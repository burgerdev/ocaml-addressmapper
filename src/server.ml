
let percent_encoding_re = Str.regexp "%\\([0-9a-f][0-9a-f]\\)"

let percent_decode =
  Str.global_substitute percent_encoding_re @@ fun x ->
    Str.replace_matched "0x\\1" x
    |> int_of_string
    |> char_of_int
    |> String.make 1

let percent_encode s =
  begin
    let ppf = Format.str_formatter in
    s |> String.iter @@
    function
    | '\x21' .. '\x7e' as c ->
      Format.fprintf ppf "%c" c
    | c ->
      int_of_char c
      |> Format.fprintf ppf "%%%02X"
  end;
  Format.flush_str_formatter ()

type request =
  | Get of string
  | Put of string
  | Health
  | Invalid of string

let request_of_string line =
  (* TODO uglyness below rings alarm bells, we should be using a parser *)
  (* BUG lowercasing here is probably not expected *)
  let line = String.lowercase_ascii line in
  try
    Scanf.sscanf line "get %s" (fun x -> Get (percent_decode x))
  with
  | Scanf.Scan_failure(_) ->
    begin
      try
        Scanf.sscanf line "put %s" (fun x -> Put (percent_decode x))
      with
      | Scanf.Scan_failure(_) ->
        begin
          if line = "health" then
            Health
          else
            Invalid line
        end
    end

let pp_request = Fmt.hbox @@ Fmt.of_to_string @@ function
  | Get s -> "get " ^ s
  | Put s -> "put " ^ s
  | Health -> "health"
  | Invalid s -> s

type response =
  | Malformed
  | Not_found
  | Internal_error
  | Unsupported
  | Found of string
  | Healthy
  | Unhealthy

let code_of_response = function
  | Found _ | Healthy -> 200
  | Internal_error | Unhealthy -> 400
  | Malformed | Not_found | Unsupported -> 500

let pp_response_code = Fmt.using code_of_response Fmt.int

let msg_of_response = function
  | Malformed -> "malformed request"
  | Not_found -> "not found"
  | Internal_error -> "internal server error"
  | Unsupported -> "not implemented"
  | Found s -> percent_encode s
  | Healthy -> "ok"
  | Unhealthy -> "not ok"

let pp_response_msg = Fmt.of_to_string msg_of_response

let pp_response =
  Fmt.using (fun x -> (x, x))
  @@ Fmt.pair ~sep:Fmt.sp pp_response_code pp_response_msg
  |> Fmt.hbox

let handle_request create_rule = function
  | Health -> begin
      try
        ignore (create_rule ());
        (* TODO log rule to debug *)
        Healthy
      with _ ->
        (* TODO log to error *)
        Unhealthy
    end
  | Invalid _ ->
    (* TODO log to info *)
    Malformed
  | Put _ ->
    (* TODO log to info *)
    Unsupported
  | Get input ->
    try
      let rule = create_rule () in
      match Mapper.apply rule input with
      | Some output -> Found output
      | None -> Not_found
    with
    | _ ->
      (* TODO log to error *)
      Internal_error

let z (f: 'a -> 'b) (g: 'b -> 'c) (x: 'a) = g @@ f x


let serve ppf create_rule stream =
  let f line =
    request_of_string line
    |> handle_request create_rule
    |> pp_response ppf;
    Format.pp_print_newline ppf ()

  in Stream.iter f stream
