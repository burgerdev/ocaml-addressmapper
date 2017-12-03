
type 'a handler = Handler of ((unit -> 'a) * (('a -> string -> string option) * 'a Fmt.t))

type request =
  | Get of string
  | Put of string
  | Health
  | Invalid of string

val request_of_string: string -> request

val pp_request: request Fmt.t

type response =
  | Malformed
  | Not_found
  | Internal_error
  | Unsupported
  | Found of string
  | Healthy
  | Unhealthy

val pp_response: response Fmt.t

val handle_request: 'a handler -> request -> response

val serve: Format.formatter -> 'a handler -> string Stream.t -> unit
