
open Sexplib

(* Grammar *)

type rule =
  | Combination of combination
  | Terminal of terminal
and combination =
  | All of rule list
  | First of rule list
  | B_rule of b_rule
and b_rule =
  | And of rule * rule
  | Or of rule * rule
  | Not of rule
and terminal =
  | Action of action
  | Transformation of transformation
and action =
  | Accept | Reject | Lower | Upper
and transformation =
  | Matches of string
  | Replace of string * string
  | Constant of string
  | Prefix of string
  | Suffix of string

exception Sexp_error of string

let terminal_of_sexp = function
  | Sexp.Atom "accept" -> Action Accept
  | Sexp.Atom "reject" -> Action Reject
  | Sexp.Atom "lower" -> Action Lower
  | Sexp.Atom "upper" -> Action Upper
  | Sexp.List [Sexp.Atom r; Sexp.Atom s] ->
    begin
      match r with
      | "matches" -> Transformation (Matches s)
      | "constant" -> Transformation (Constant s)
      | "prefix_matches" -> Transformation (Prefix s)
      | "suffix_matches" -> Transformation (Suffix s)
      | _ ->
        Conv.of_sexp_error "can't parse unary transformation" (Sexp.Atom r)
    end
  | Sexp.List [Sexp.Atom r; Sexp.Atom s1; Sexp.Atom s2] ->
    begin
      match r with
      | "replace" -> Transformation (Replace (s1, s2))
      | _ ->
        Conv.of_sexp_error "can't parse binary transformation" (Sexp.Atom r)
    end
  | s -> Conv.of_sexp_error "can't parse terminal rule of sexp" s

exception Stop_parsing of Sexp.t

let tree_of_sexp sexp =
  let rec aux sexp =
    let combination_of_sexp = function
      | Sexp.List [left; Sexp.Atom "&&"; right] ->
        B_rule (And (aux left, aux right))
      | Sexp.List [left; Sexp.Atom "||"; right] ->
        B_rule (Or (aux left, aux right))
      | Sexp.List [Sexp.Atom "not"; r] ->
        B_rule (Not (aux r))
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

let rec mapper_rule_of_tree tree =
  let rule_of_terminal = function
    | Action Accept -> Mapper.accept
    | Action Reject -> Mapper.reject
    | Action Lower -> Mapper.lower
    | Action Upper -> Mapper.upper
    | Transformation (Matches pattern) -> Mapper.matches pattern
    | Transformation (Replace (pattern, replacement)) ->
      Mapper.replace pattern replacement
    | Transformation (Constant replacement) -> Mapper.constant replacement
    | Transformation (Prefix prefix) -> Mapper.prefix_matches prefix
    | Transformation (Suffix suffix) -> Mapper.suffix_matches suffix
  in

  let rule_of_combination = function
    | All l -> Mapper.all (List.map mapper_rule_of_tree l)
    | First l -> Mapper.first (List.map mapper_rule_of_tree l)
    | B_rule b ->
      begin
        match b with
        | And (t1, t2) -> Mapper.all (List.map mapper_rule_of_tree [t1; t2])
        | Or (t1, t2) -> Mapper.first (List.map mapper_rule_of_tree [t1; t2])
        | Not t -> Mapper.not (mapper_rule_of_tree t)
      end
  in

  match tree with
  | Combination c -> rule_of_combination c
  | Terminal t -> rule_of_terminal t

let rule_of_sexp sexp =
  let tree = tree_of_sexp sexp in
  mapper_rule_of_tree tree
