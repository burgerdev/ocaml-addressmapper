
(** [Handler (get_rule, apply_rule, pp_rule)] is the data needed to serve requests.
    [get_rule] is called to initialize the rule, then input and rule are handed
    to [apply_rule]. [pp_rule] is used for debug logging. *)
type 'a handler = Handler of (unit -> 'a) * ('a -> string -> string option) * 'a Fmt.t


(** Type of requests that the server anticipates. The only request that is
    expected to come from postfix is [Get s], [Put s] is specified but neither
    implemented in postfix nor here and [Health] is used to check the server's
    status. Every other incoming request is wrapped in an [Other]. *)
type request =
  | Get of string
  | Put of string
  | Health
  | Other of string


val request_of_string: string -> request
(** [request_of_string req] tries to parse the string [req] according to the
    grammar defined in the
    {{: http://www.postfix.org/tcp_table.5.html } postfix manual }. *)

val pp_request: request Fmt.t
(** Pretty printer for [type request]. *)

(** Type of responses that the server creates. *)
type response =
  | Malformed
  | Not_found
  | Internal_error
  | Unsupported
  | Found of string
  | Healthy
  | Unhealthy

val pp_response: response Fmt.t
(** Pretty printer for [type response] *)

val handle_request: 'a handler -> request -> response
(** [handle_request handler req] uses [handler] to respond to [req]. *)

val serve: Format.formatter -> 'a handler -> string Stream.t -> unit
(** [serve ppf handler stream] establishes a server that handles requests coming
    from [stream] with [handler] and writes the results to [ppf]. *)
