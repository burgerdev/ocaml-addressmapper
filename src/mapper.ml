
open Sexplib

type leaf = (* TODO regexify *)
  | Matches of string
  | Replace of string * string
  | Accept
  | Reject

type t =
  | All of t list
  | First of t list
  | Leaf of leaf

let all ts = All ts
let first ts = First ts
let matches s = Leaf (Matches s)
let replace s1 s2 = Leaf (Replace (s1, s2))
let accept = Leaf (Accept)
let reject = Leaf (Reject)

let rec traverse s tree =
  match tree with
  | Leaf (Accept) -> Some s
  | Leaf (Reject) -> None
  | Leaf (Matches pattern) ->
    begin
      try
        let _ = Str.search_forward (Str.regexp pattern) s 0 in
        Some s
      with
      | Not_found -> None
    end
  | Leaf (Replace (pattern, replacement)) ->
    Some (Str.replace_first (Str.regexp pattern) replacement s)
  | All [] -> Some s
  | All [h] -> traverse s h
  | All (h :: t) ->
    begin
      match traverse s (All [h]) with
      | Some s1 -> traverse s1 (All t)
      | None -> None
    end
  | First [] -> Some s
  | First [h] -> traverse s h
  | First (h :: t) ->
    begin
      match traverse s (First [h]) with
      | Some s1 -> Some s1
      | None -> traverse s (First t)
    end

let accept_s = "accept"
let reject_s = "reject"
let matches_s = "matches"
let replace_s = "replace"
let all_s = "all"
let first_s = "first"

exception Sexp_error of string

let matches_of_list = function
  | [Sexp.Atom pattern] -> Leaf (Matches pattern)
  | _ -> raise (Sexp_error "invalid sexp for 'matches' keyword")

let replace_of_list = function
  | [Sexp.Atom pattern; Sexp.Atom replacement] ->
    Leaf (Replace (pattern, replacement))
  | _ -> raise (Sexp_error "invalid sexp for 'replace' keyword")

let t_of_sexp_list t_of_sexp = function
  | [] -> raise (Sexp_error "invalid sexp: empty list")
  | h :: t ->
    match h with
    | Sexp.Atom s when s = all_s -> All (List.map t_of_sexp t)
    | Sexp.Atom s when s = first_s -> First (List.map t_of_sexp t)
    | Sexp.Atom s when s = matches_s -> matches_of_list t
    | Sexp.Atom s when s = replace_s -> replace_of_list t
    | other ->
      let msg = Printf.sprintf "invalid sexp: %s" (Sexp.to_string other) in
      raise (Sexp_error msg)

let t_of_string = function
  | s when s = accept_s -> Leaf (Accept)
  | s when s = reject_s -> Leaf (Reject)
  | s ->
    let msg = Printf.sprintf "invalid sexp: atom %s" s in
    raise (Sexp_error msg)

let rec t_of_sexp =
  function
  | Sexp.Atom s -> t_of_string s
  | Sexp.List l -> t_of_sexp_list t_of_sexp l

let rec sexp_of_t = function
  | Leaf (Accept) -> Sexp.Atom accept_s
  | Leaf (Reject) -> Sexp.Atom reject_s
  | Leaf (Matches pattern) ->
    Sexp.List [Sexp.Atom matches_s; Sexp.Atom pattern ]
  | Leaf (Replace (pattern, replacement)) ->
    Sexp.List [Sexp.Atom replace_s; Sexp.Atom pattern; Sexp.Atom replacement]
  | All ts ->  Sexp.List (Sexp.Atom all_s :: List.map sexp_of_t ts)
  | First ts -> Sexp.List (Sexp.Atom first_s :: List.map sexp_of_t ts)
