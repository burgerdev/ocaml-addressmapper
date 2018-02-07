open Mapper_helper
open Mapper_rule
open Sexplib.Sexp
open Mapper_predef

let rule_alg = function
  | Terminal (_, f) -> f
  | Not f -> fun input -> f input |> Option.invert input
  | First fs -> List.fold_left Option.(<|>) (fun _ -> None) fs
  | All fs -> Option.(List.fold_left (>=>) return fs)

let sexp_coalg = function
  | List [Atom "not"; sub] -> Not sub
  | List [Atom "first"; List subs] -> First subs
  | Atom "accept" -> accept
  | Atom "reject" -> reject
  | Atom "lower" -> lower
  | Atom "upper" -> upper
  | List [Atom "constant"; Atom x] -> constant x
  | List [Atom "equals"; Atom x] -> equals x
  | List [Atom "matches"; Atom x] -> matches x
  | List [Atom "prefix_matches"; Atom x] -> prefix_matches x
  | List [Atom "suffix_matches"; Atom x] -> suffix_matches x
  | List [Atom "replace"; Atom x; Atom y] -> replace x y
  | List [l; Atom "&&"; r] -> All [l; r]
  | List [l; Atom "||"; r] -> First [l; r]
  | List subs -> All subs
  | Atom _ as u -> Sexplib.Conv.of_sexp_error "could not parse atom" u

let sexp_alg = function
  | All subs -> List subs
  | First subs -> List [Atom "first"; List subs]
  | Not sub -> List [Atom "not"; sub]
  | Terminal (pp, _) ->
    (* HACK *)
    Fmt.strf "%a" pp () |> Sexplib.Sexp.of_string

let pp_alg =
  let open Fmt in
  function
  | All pps -> pp_of_pp_list pps |> boxed_parens
  | First pps ->
    let sub = pp_of_pp_list pps |> boxed_parens in
    str "first" >>> sub |> boxed_parens
  | Not pp -> str "not" >>> pp |> boxed_parens
  | Terminal (pp, _) -> pp

let name_alg =
  let open Fmt in
  function
  | All _ -> str "all"
  | First _ -> str "first"
  | Not _ -> str "not"
  | Terminal (pp, _) -> pp

let depth_alg = function
  | All subs | First subs -> List.fold_left max 0 subs
  | Not d -> d + 1
  | Terminal _ -> 0
