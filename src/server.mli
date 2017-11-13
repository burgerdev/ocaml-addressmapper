
type request =
  | Get of string
  | Put of string
  | Health
  | Invalid of string

val request_of_string: string -> request

val string_of_request: request -> string

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

val string_of_response: response -> string
