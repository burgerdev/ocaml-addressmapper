type ('a, 'b) rule = Rule of ('a -> 'b option)

let return f = Rule f

let accept = Rule (fun x -> Some x)
let reject = Rule (fun _ -> None)

let apply r a =
  let (Rule f) = r in f a

let bind r f =
  let f_after_r a =
    match apply r a with
    | None -> None
    | Some b -> f b
  in return f_after_r

let all rules =
  let rec aux acc_rule = function
    | [] -> acc_rule
    | h :: t ->
      aux (bind acc_rule (apply h)) t
  in aux accept rules

let bind_alt r f =
  let maybe_f a =
    match apply r a with
    | None -> f a
    | res -> res
  in return maybe_f

let first rules =
  let rec aux acc_rule = function
    | [] -> acc_rule
    | h :: t ->
      aux (bind_alt acc_rule (apply h)) t
  in aux reject rules

let not rule =
  let invert input =
    match apply rule input with
    | Some _ -> None
    | None -> Some input
  in return invert

let matches pattern =
  let handler input =
    try
      let _ = Str.search_forward (Str.regexp pattern) input 0 in
      Some input
    with
    | Not_found -> None
  in return handler

let replace pattern replacement =
  let handler input =
    Some (Str.replace_first (Str.regexp pattern) replacement input)
  in return handler

let lower = return (fun input -> Some (String.lowercase_ascii input))
let upper = return (fun input -> Some (String.uppercase_ascii input))
let constant c = return (fun _ -> Some c)
