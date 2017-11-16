
open Sexplib

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
  | Matches of string
  | Replace of string * string
  | Constant of string
  | Prefix of string
  | Suffix of string

let log_src = Logs.Src.create "mapper"

let log_debug f = Logs.debug ?src:(Some log_src) f

let pp_combination ppf = function
  | All _ -> Format.fprintf ppf "all"
  | First _ -> Format.fprintf ppf "first"
  | _ -> Format.fprintf ppf "<?>" (* TODO *)

let pp_terminal ppf = function
  | Accept -> Format.fprintf ppf "accept"
  | Reject -> Format.fprintf ppf "reject"
  | _ -> Format.fprintf ppf "<?>"

let pp_opt ppf = function
  | Some x -> Format.fprintf ppf "Some(%s)" x
  | None -> Format.fprintf ppf "None"

let rec indent n fmt =
  if n = 0 then
    fmt
  else
    indent (n - 1) ((format_of_string "| ") ^^ fmt)

exception Stop_evaluating of string option

let apply_combination n apply_rule combination input =
  let and_then result rule =
    match result with
    | None -> raise (Stop_evaluating None)
    | Some x -> apply_rule rule x in

  let or_else result rule =
    match result with
    | None -> apply_rule rule input
    | Some x -> raise (Stop_evaluating (Some x)) in

  let fmt = indent n "Evaluating combination [%a] on [%s]:" in
  log_debug (fun m -> m fmt pp_combination combination input);

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
    with Stop_evaluating r -> r  in
  log_debug (fun m -> m (indent n "Got %a.") pp_opt result);
  result

let apply_terminal n terminal input =
  let result = match terminal with
  | Accept -> Some input
  | Reject -> None
  | Lower -> Some (String.lowercase_ascii input)
  | Upper -> Some (String.uppercase_ascii input)
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

  let fmt = indent n "rule [%a] mapped [%s] to [%a]" in
  log_debug (fun m -> m fmt pp_terminal terminal input pp_opt result);
  result

let apply rule input =
  let rec aux depth rule input =
    match rule with
    | Combination c -> apply_combination depth (aux (succ depth)) c input
    | Terminal t -> apply_terminal depth t input
  in aux 0 rule input

exception Sexp_error of string

let terminal_of_sexp = function
  | Sexp.Atom "accept" -> Accept
  | Sexp.Atom "reject" -> Reject
  | Sexp.Atom "lower" -> Lower
  | Sexp.Atom "upper" -> Upper
  | Sexp.List [Sexp.Atom r; Sexp.Atom s] ->
    begin
      match r with
      | "matches" -> Matches s
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

exception Stop_parsing of Sexp.t

let rule_of_sexp sexp =
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

let accept = Terminal Accept

let reject = Terminal Reject

let all rules = Combination (All rules)

let first rules = Combination (First rules)

let not rule = Combination (Not rule)

let matches pattern = Terminal (Matches pattern)

let replace pattern replacement = Terminal (Replace (pattern, replacement))

let prefix_matches prefix = Terminal (Prefix prefix)

let suffix_matches suffix = Terminal (Suffix suffix)

let lower = Terminal Lower

let upper = Terminal Upper

let constant c = Terminal (Constant c)
