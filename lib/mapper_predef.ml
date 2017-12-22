(* predefined rules *)

open Mapper_rule

let lower = create "lower" @@ fun input -> Some (String.lowercase_ascii input)
let upper = create "upper" @@ fun input -> Some (String.uppercase_ascii input)

let escaped = Fmt.(fmt "%S")

let pp_unary name arg = Some Fmt.(
    const escaped arg
    |> prefix sp
    |> prefix @@ const string name
    |> parens
    |> hbox
  )

let pp_binary name arg1 arg2 = Some Fmt.(
    const escaped arg2
    |> prefix sp
    |> prefix @@ const escaped arg1
    |> prefix sp
    |> prefix @@ const string name
    |> parens
    |> hbox
  )

let constant replacement =
  create_pp (pp_unary "constant" replacement) @@ fun _ -> Some replacement

let equals pattern =
  let f = fun input -> if pattern = input then Some input else None in
  create_pp (pp_unary "equals" pattern) f

let matches pattern =
  let f = fun input ->
    try
      let _ = Str.search_forward (Str.regexp pattern) input 0 in
      Some input
    with
    | Not_found -> None
  in
  create_pp (pp_unary "matches" pattern) f

let replace pattern replacement =
  let f input = Some (Str.replace_first (Str.regexp pattern) replacement input) in
  create_pp (pp_binary "replace" pattern replacement) f

let prefix_matches pattern =
  let n = String.length pattern in
  let f input =
    if String.length input >= n && String.sub input 0 n = pattern then
      Some input
    else
      None
  in
  create_pp (pp_unary "prefix_matches" pattern) f

let suffix_matches pattern =
  let n = String.length pattern in
  let f input =
  let m = String.length input in
  if m >= n && String.sub input (m-n) n = pattern then
    Some input
  else
    None
  in
  create_pp (pp_unary "suffix_matches" pattern) f
