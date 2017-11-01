type rule = Rule of (string -> string option)

let label name rule =
  let (Rule f) = rule in
  let f_with_log x =
    let y_opt = f x in
    begin
      match y_opt with
      | Some y ->
        Logs.debug (fun m -> m "Rule [%s]: mapped [%s] to [%s]" name x y)
      | None ->
        Logs.debug (fun m -> m "Rule [%s]: did not apply to [%s]" name x)
    end;
    y_opt
  in Rule f_with_log

let label_quietly name rule =
  let (Rule f) = rule in
  let f_with_log x =
    let y_opt = f x in
    begin
      match y_opt with
      | Some _ ->
        Logs.debug (fun m -> m "Rule [%s]: applied." name)
      | None ->
        Logs.debug (fun m -> m "Rule [%s]: did not apply." name)
    end;
    y_opt
  in Rule f_with_log

let return f = Rule f

let apply r a =
  let (Rule f) = r in f a

let and_then r1 r2 =
  let g_after_f input = match apply r1 input with
    | None -> None
    | Some x -> apply r2 x
  in return g_after_f

let or_else r1 r2 =
  let g_after_f input = match apply r1 input with
    | None -> apply r2 input
    | Some x -> Some x
  in return g_after_f

let accept =
  let rule = return (fun x -> Some x) in
  label_quietly "accept" rule

let reject =
  let rule = return (fun _ -> None) in
  label_quietly "reject" rule

let all rules =
  let init = return (fun x -> Some x) in
  let rule = List.fold_left and_then init rules in
  label_quietly "all" rule

let first rules =
  let init = return (fun _ -> None) in
  let rule = List.fold_left or_else init rules in
  label_quietly "first" rule

let not rule =
  let invert input =
    match apply rule input with
    | Some _ -> None
    | None -> Some input
  in label_quietly "not" (return invert)

let matches pattern =
  let re = (Str.regexp pattern) in
  let handler input =
    try
      let _ = Str.search_forward re input 0 in
      Some input
    with
    | Not_found -> None
  in label (Printf.sprintf "matches(\"%s\")" pattern) (return handler)

let prefix_matches prefix =
  let n = String.length prefix in
  let handler input =
    if String.length input >= n && String.sub input 0 n = prefix then
      Some input
    else
      None
  in label (Printf.sprintf "prefix_matches(\"%s\")" prefix) (return handler)

let suffix_matches suffix =
  let n = String.length suffix in
  let handler input =
    let m = String.length input in
    if m >= n && String.sub input (m-n) n = suffix then
      Some input
    else
      None
  in label (Printf.sprintf "suffix_matches(\"%s\")" suffix) (return handler)

let replace pattern replacement =
  let repl = Str.replace_first (Str.regexp pattern) replacement in
  let handler input = Some (repl input) in
  label (Printf.sprintf "replace(\"%s\", \"%s\")" pattern replacement) (return handler)

let lower = label "lower" (return (fun input -> Some (String.lowercase_ascii input)))
let upper = label "upper" (return (fun input -> Some (String.uppercase_ascii input)))
let constant c = label "constant" (return (fun _ -> Some c))
