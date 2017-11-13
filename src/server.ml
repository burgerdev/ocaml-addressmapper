

type request =
  | Get of string
  | Put of string
  | Health
  | Invalid of string

let request_of_string line =
  (* TODO uglyness below rings alarm bells, we should be using a parser *)
  let line = String.lowercase_ascii line in
  try
    Scanf.sscanf line "get %s" (fun x -> Get x)
  with
  | Scanf.Scan_failure(_) ->
    begin
      try
        Scanf.sscanf line "put %s" (fun x -> Put x)
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
  | Found s -> Format.sprintf "200 %s\n" s
  | Health Rules_ok -> "ok\n"
  | Health Rules_error -> "error\n"
