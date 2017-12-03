(* business logic for rule evaluation *)

open Mapper_rule

module R = struct
  let accept input = Some input
  let reject _input = None
  let lower input = Some (String.lowercase_ascii input)
  let upper input = Some (String.uppercase_ascii input)
  let constant replacement _input = Some replacement

  let equals pattern input =
    if pattern = input then Some input else None

  let matches pattern input =
    try
      let _ = Str.search_forward (Str.regexp pattern) input 0 in
      Some input
    with
    | Not_found -> None

  let replace pattern replacement input =
    Some (Str.replace_first (Str.regexp pattern) replacement input)
  let prefix pattern input =
    let n = String.length pattern in
    if String.length input >= n && String.sub input 0 n = pattern then
      Some input
    else
      None

  let suffix pattern input =
    let n = String.length pattern in
    let m = String.length input in
    if m >= n && String.sub input (m-n) n = pattern then
      Some input
    else
      None

  let and_then f = function
    | None -> None
    | Some x -> f x

  let or_else f = function
    | Some x -> Some x
    | None -> f ()

  let all evaluate rules input =
    List.fold_left (fun opt rule -> opt |> and_then @@ evaluate rule) (Some input) rules
  let first evaluate rules input =
    List.fold_left (fun opt rule -> opt |> or_else @@ fun () -> evaluate rule input) None rules
  let not_rule evaluate rule input = match evaluate rule input with
    | Some _ -> None
    | None -> Some input

end

let rec fun_of_rule =
  let fun_of_terminal = function
    | Accept -> R.accept
    | Reject -> R.reject
    | Lower -> R.lower
    | Upper -> R.upper
    | Equals s -> R.equals s
    | Matches s -> R.matches s
    | Replace (pattern, replacement) -> R.replace pattern replacement
    | Constant s -> R.constant s
    | Prefix s -> R.prefix s
    | Suffix s -> R.suffix s
  in
  let fun_of_combination = function
    | All rules -> R.all fun_of_rule rules
    | First rules -> R.first fun_of_rule rules
    | And (r1, r2) -> R.all fun_of_rule [r1; r2]
    | Or (r1, r2) -> R.first fun_of_rule [r1; r2]
    | Not rule -> R.not_rule fun_of_rule rule
  in
  function Terminal t -> fun_of_terminal t | Combination c -> fun_of_combination c
