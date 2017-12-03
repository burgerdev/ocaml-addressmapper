open Fmt
open Sexplib
open Mapper_rule


type rule = Mapper_rule.rule

(* printer *)

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

(* parser *)

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
