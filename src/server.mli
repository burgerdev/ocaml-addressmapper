
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

val handle_request: (unit -> Mapper.rule) -> request -> response

val serve: Format.formatter -> (unit -> Mapper.rule) -> string Stream.t -> unit
