open Mapper_rule
open Mapper_helper

let basic name f = Terminal (Fmt.(str name), f)
let unary name f x = Terminal (Fmt.(str name >>> str x |> parens), f x)
let binary name f x y = Terminal (Fmt.(str name >>> str x >>> str y |> parens), f x y)

let accept = (fun x -> Some x)
let accept = basic "accept" accept

let reject = (fun _ -> None)
let reject = basic "reject" reject

let lower x = Some (String.lowercase_ascii x)
let lower = basic "lower" lower

let upper x = Some (String.uppercase_ascii x)
let upper = basic "upper" upper

let constant x _ = Some x
let constant = unary "constant" constant

let equals pattern x =
  if x = pattern then
    Some x
  else
    None
let equals = unary "equals" equals

let matches pattern x =
  try
    let _ = Str.search_forward (Str.regexp pattern) x 0 in
    Some x
  with
  | Not_found -> None
let matches = unary "matches" matches

let replace pattern replacement x =
  Some (Str.replace_first (Str.regexp pattern) replacement x)
let replace = binary "replace" replace

let prefix_matches pattern =
  let n = String.length pattern in
  fun x ->
    if String.length x >= n && String.sub x 0 n = pattern then
      Some x
    else
      None
let prefix_matches = unary "prefix_matches" prefix_matches

let suffix_matches pattern =
  let n = String.length pattern in
  fun x ->
    let m = String.length x in
    if m >= n && String.sub x (m-n) n = pattern then
      Some x
    else
      None
let suffix_matches = unary "suffix_matches" suffix_matches
