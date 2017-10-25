type ('a, 'b) rule = Rule of ('a -> 'b option)

let return_nolog f = Rule f

let default_fmt _ = "<?>"
let default_fmt_opt = function
  | Some _ -> "Some(<?>)"
  | None -> "None"

let return_named
    ?fmt_input:(fi: ('a -> string)=default_fmt)
    ?fmt_output:(fo: ('b option -> string)=default_fmt_opt)
    name (f: 'a -> 'b option) =
  let f_with_log x =
    let y = f x in
    Logs.debug (fun m -> m "Applied [%s]: mapped [%s] to [%s]" name (fi x) (fo y));
    y
  in return_nolog f_with_log

let return_named_string name =
  let fi x = x in
  let fo = function
    | Some s -> Printf.sprintf "Some(%s)" s
    | None -> "None"
  in return_named ~fmt_input:fi ~fmt_output:fo name

let return f = return_named "<anonymous mapper>" f

let apply r a =
  let (Rule f) = r in f a

let and_then r1 r2 =
  let g_after_f input = match apply r1 input with
    | None -> None
    | Some x -> apply r2 x
  in return_nolog g_after_f

let or_else r1 r2 =
  let g_after_f input = match apply r1 input with
    | None -> apply r2 input
    | Some x -> Some x
  in return_nolog g_after_f

let accept =
  let log _ = Logs.debug (fun m -> m "Applied [accept].") in
  Rule (fun x -> log (); Some x)

let accept_nolog = Rule (fun x -> Some x)

let reject =
  let log _ = Logs.debug (fun m -> m "Applied [reject].") in
  Rule (fun _ -> log (); None)

let reject_nolog = Rule (fun _ -> None)

let all rules =
  let rule = List.fold_left and_then accept_nolog rules in
  return_named "all" (apply rule)

let first rules =
  let rule = List.fold_left or_else reject_nolog rules in
  return_named "first" (apply rule)

let not rule =
  let invert input =
    match apply rule input with
    | Some _ -> None
    | None -> Some input
  in return_named "not" invert

let matches pattern =
  let re = (Str.regexp pattern) in
  let handler input =
    try
      let _ = Str.search_forward re input 0 in
      Some input
    with
    | Not_found -> None
  in return_named_string (Printf.sprintf "matches(\"%s\")" pattern) handler

let prefix_matches prefix =
  let n = String.length prefix in
  let handler input =
    if String.length input >= n && String.sub input 0 n = prefix then
      Some input
    else
      None
  in return_named_string (Printf.sprintf "prefix_matches(\"%s\")" prefix) handler

let suffix_matches suffix =
  let n = String.length suffix in
  let handler input =
    let m = String.length input in
    if m >= n && String.sub input (m-n) n = suffix then
      Some input
    else
      None
  in return_named_string (Printf.sprintf "suffix_matches(\"%s\")" suffix) handler

let replace pattern replacement =
  let repl = Str.replace_first (Str.regexp pattern) replacement in
  let handler input = Some (repl input) in
  return_named_string (Printf.sprintf "replace(\"%s\", \"%s\")" pattern replacement) handler

let lower = return_named_string "lower" (fun input -> Some (String.lowercase_ascii input))
let upper = return_named_string "upper" (fun input -> Some (String.uppercase_ascii input))
let constant c = return_named_string "constant" (fun _ -> Some c)
let constant c =
  let log _ = Logs.debug (fun m -> m "Applied [constant].") in
  Rule (fun _ -> log (); Some c)
