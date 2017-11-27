
open Sexplib

open Fmt

(* Grammar *)

type rule =
  | Combination of combination
  | Terminal of terminal
and combination =
  | All of rule list
  | First of rule list
  | And of rule * rule
  | Or of rule * rule
  | Not of rule
and terminal =
  | Accept | Reject | Lower | Upper
  | Equals of string
  | Matches of string
  | Replace of string * string
  | Constant of string
  | Prefix of string
  | Suffix of string

type t = rule

let log_src = Logs.Src.create "mapper"

module Mapper_log = (val (Logs.src_log log_src))

let string_of_combination = function
  | All _ -> "all"
  | First _ -> "first"
  | And _ -> "and"
  | Or _ -> "or"
  | Not _ -> "not"

let pp_combination = of_to_string string_of_combination

let string_of_terminal = function
  | Accept -> "accept"
  | Reject -> "reject"
  | Lower -> "lower"
  | Upper -> "upper"
  | Constant s -> strf "(constant \"%s\")" s
  | Equals s -> strf "(equals \"%s\")" s
  | Matches s -> strf "(matches \"%s\")" s
  | Replace (a, b) -> strf "(replace \"%s\" \"%s\")" a b
  | Prefix s -> strf "(prefix_matches \"%s\")" s
  | Suffix s -> strf "(suffix_matches \"%s\")" s

let pp_terminal = of_to_string string_of_terminal

let string_of_rule = function
  | Combination c -> string_of_combination c
  | Terminal t -> string_of_terminal t

let pp_rule = of_to_string string_of_rule
let pp = pp_rule

let pp_opt =
  brackets  string
  |> option ~none:(unit "None")

let braced_list_of pp =
  list ~sep:sp pp
  |> hvbox ~indent:1
  |> parens

let dump_terminal =
  pp_terminal
  |> hbox

let rec dump_rule ppf = function
  | Combination c -> dump_combination ppf c
  | Terminal t -> dump_terminal ppf t
and dump_combination ppf c =
  pf ppf "(";
  Format.pp_open_hovbox ppf 1;
  begin match c with
    | All rules -> rules |> list ~sep:sp dump_rule @@ ppf
    | First rules -> pf ppf "first@ %a" (braced_list_of dump_rule) rules
    | And (l, r) -> pf ppf "@[<hov2>%a@ &&@ %a@]" dump_rule l dump_rule r
    | Or (l, r) -> pf ppf "@[<hov2>%a@ ||@ %a@]" dump_rule l dump_rule r
    | Not r -> pf ppf "@[<hov2>not@ %a@]" dump_rule r
  end;
  Format.pp_close_box ppf ();
  pf ppf ")"

let dump = dump_rule

let rec indent n pp =
  if n = 0 then
    pp
  else
    indent (n - 1) @@ prefix (const string "| ") pp

let log_result n rule input output_opt =
  let pp_msg = fun ppf () -> match output_opt with
    | Some output ->
      fmt "rule [%a] mapped [%s] to [%s]" ppf pp_rule rule input output
    | None ->
      fmt "rule [%a] rejected [%s]" ppf pp_rule rule input
  in
  let pp_msg = indent n pp_msg in
  Mapper_log.debug @@ fun m -> m "%a" pp_msg ()

let apply_combination n apply_rule combination input =

  let exception Stop_evaluating of string option in

  let and_then result rule =
    match result with
    | None -> raise (Stop_evaluating None)
    | Some x -> apply_rule rule x in

  let or_else result rule =
    match result with
    | None -> apply_rule rule input
    | Some x -> raise (Stop_evaluating (Some x)) in

  (* TODO improve indented logging *)
  let pp_indent: unit Fmt.t = indent n @@ const string "" in
  Mapper_log.debug (fun m ->
      (m "%a(%a) on [%s]:")
        pp_indent () pp_combination combination input);

  let result =
    try
      match combination with
      | All rules -> List.fold_left and_then (Some input) rules
      | And (r1, r2) -> List.fold_left and_then (Some input) [r1; r2]
      | First rules -> List.fold_left or_else None rules
      | Or (r1, r2) -> List.fold_left or_else None [r1; r2]
      | Not rule ->
        match apply_rule rule input with
        | Some _ -> None
        | None -> Some input
    with Stop_evaluating r -> r
  in
  log_result n (Combination combination) input result;
  result

let apply_terminal n terminal input =
  let result = match terminal with
  | Accept -> Some input
  | Reject -> None
  | Lower -> Some (String.lowercase_ascii input)
  | Upper -> Some (String.uppercase_ascii input)
  | Equals s when s = input -> Some s
  | Equals _ -> None
  | Matches pattern ->
    begin
      try
        let _ = Str.search_forward (Str.regexp pattern) input 0 in
        Some input
      with
      | Not_found -> None
    end
  | Replace (pattern, replacement) ->
    Some (Str.replace_first (Str.regexp pattern) replacement input)
  | Constant c -> Some c
  | Prefix prefix ->
    let n = String.length prefix in
    if String.length input >= n && String.sub input 0 n = prefix then
      Some input
    else
      None
  | Suffix suffix ->
    let n = String.length suffix in
    let m = String.length input in
    if m >= n && String.sub input (m-n) n = suffix then
      Some input
    else
      None
  in

  log_result n (Terminal terminal) input result;
  result

let apply rule input =
  let rec aux depth rule input =
    match rule with
    | Combination c -> apply_combination depth (aux (succ depth)) c input
    | Terminal t -> apply_terminal depth t input
  in aux 0 rule input

let terminal_of_sexp = function
  | Sexp.Atom "accept" -> Accept
  | Sexp.Atom "reject" -> Reject
  | Sexp.Atom "lower" -> Lower
  | Sexp.Atom "upper" -> Upper
  | Sexp.List [Sexp.Atom r; Sexp.Atom s] ->
    begin
      match r with
      | "matches" -> Matches s
      | "equals" -> Equals s
      | "constant" -> Constant s
      | "prefix_matches" -> Prefix s
      | "suffix_matches" -> Suffix s
      | _ ->
        Conv.of_sexp_error "can't parse unary transformation" (Sexp.Atom r)
    end
  | Sexp.List [Sexp.Atom r; Sexp.Atom s1; Sexp.Atom s2] ->
    begin
      match r with
      | "replace" -> Replace (s1, s2)
      | _ ->
        Conv.of_sexp_error "can't parse binary transformation" (Sexp.Atom r)
    end
  | s -> Conv.of_sexp_error "can't parse terminal rule of sexp" s

let rule_of_sexp sexp =
  let exception Stop_parsing of Sexp.t in
  let rec aux sexp =
    let combination_of_sexp = function
      | Sexp.List [left; Sexp.Atom "&&"; right] ->
        And (aux left, aux right)
      | Sexp.List [left; Sexp.Atom "||"; right] ->
        Or (aux left, aux right)
      | Sexp.List [Sexp.Atom "not"; r] ->
        Not (aux r)
      | Sexp.List [Sexp.Atom "first"; Sexp.List t] ->
        First (List.map aux t)
      | Sexp.List l ->
        All (List.map aux l)
      | sexp -> Conv.of_sexp_error "can't parse combination rule of sexp" sexp
    in
    try
      Terminal (terminal_of_sexp sexp)
    with
    | Conv.Of_sexp_error (_, _) ->
      try
        Combination (combination_of_sexp sexp)
      with
      | Conv.Of_sexp_error (_, _) ->
        raise (Stop_parsing sexp)
  in
  try
    aux sexp
  with
  | Stop_parsing sexp ->
    Conv.of_sexp_error "could neither parse terminal nor combination" sexp

let t_of_sexp = rule_of_sexp

(* TODO create sexp directly *)
let sexp_of_rule rule =
  strf "%a" dump rule
  |> Sexplib.Sexp.of_string

let sexp_of_t = sexp_of_rule

let accept = Terminal Accept

let reject = Terminal Reject

let all rules = Combination (All rules)

let first rules = Combination (First rules)

let not rule = Combination (Not rule)

let matches pattern = Terminal (Matches pattern)

let equals other = Terminal (Equals other)

let replace pattern replacement = Terminal (Replace (pattern, replacement))

let prefix_matches prefix = Terminal (Prefix prefix)

let suffix_matches suffix = Terminal (Suffix suffix)

let lower = Terminal Lower

let upper = Terminal Upper

let constant c = Terminal (Constant c)
