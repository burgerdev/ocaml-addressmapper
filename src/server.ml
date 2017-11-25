
let percent_encoding_re = Str.regexp "%\\([0-9a-f][0-9a-f]\\)"

let string_of_percent_encoding request_string =
  request_string
  |> Str.replace_matched "0x\\1"
  |> int_of_string
  |> char_of_int
  |> String.make 1

let percent_decode =
  Str.global_substitute percent_encoding_re string_of_percent_encoding

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

let string_of_request = function
  | Get s -> "get " ^ s
  | Put s -> "put " ^ s
  | Health -> "health"
  | Invalid s -> s

type health =
  | Rules_ok
  | Rules_error

type response =
  | Malformed
  | Not_found
  | Internal_error of exn
  | Unsupported
  | Found of string
  | Health of health

let string_of_response = function
  | Malformed -> "400 malformed request\n"
  | Not_found -> "500 not-found\n"
  | Internal_error _ -> "500 internal server error\n"
  | Unsupported -> "500 not-implemented\n"
  (* TODO percent-encode *)
  | Found s -> Format.sprintf "200 %s\n" s
  | Health Rules_ok -> "ok\n"
  | Health Rules_error -> "error\n"
