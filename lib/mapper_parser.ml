
open Mapper_rule
open Mapper_predef
open Sexplib

(* parser *)

let terminal_of_sexp = function
  | Sexp.Atom "accept" -> accept
  | Sexp.Atom "reject" -> reject
  | Sexp.Atom "lower" -> lower
  | Sexp.Atom "upper" -> upper
  | Sexp.List [Sexp.Atom r; Sexp.Atom s] ->
    begin
      match r with
      | "matches" -> matches s
      | "equals" -> equals s
      | "constant" -> constant s
      | "prefix_matches" -> prefix_matches s
      | "suffix_matches" -> suffix_matches s
      | _ ->
        Conv.of_sexp_error "can't parse unary transformation" (Sexp.Atom r)
    end
  | Sexp.List [Sexp.Atom r; Sexp.Atom s1; Sexp.Atom s2] ->
    begin
      match r with
      | "replace" -> replace s1 s2
      | _ ->
        Conv.of_sexp_error "can't parse binary transformation" (Sexp.Atom r)
    end
  | s -> Conv.of_sexp_error "can't parse terminal rule of sexp" s

let rule_of_sexp sexp =
  let exception Stop_parsing of Sexp.t in
  let rec aux sexp =
    let combination_of_sexp = function
      | Sexp.List [left; Sexp.Atom "&&"; right] ->
        all [aux left; aux right]
      | Sexp.List [left; Sexp.Atom "||"; right] ->
        first [aux left; aux right]
      | Sexp.List [Sexp.Atom "not"; r] ->
        invert (aux r)
      | Sexp.List [Sexp.Atom "first"; Sexp.List t] ->
        first (List.map aux t)
      | Sexp.List l ->
        all (List.map aux l)
      | sexp ->
        Conv.of_sexp_error "can't parse combination rule of sexp" sexp
    in
    try
      terminal_of_sexp sexp
    with
    | Conv.Of_sexp_error (_, _) ->
      try
        combination_of_sexp sexp
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
  Fmt.strf "%a" pp rule
  |> Sexplib.Sexp.of_string

let sexp_of_t = sexp_of_rule
