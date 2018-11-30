type rule
type t = rule

val create: string -> (string -> string option) -> t
val create_pp: unit Fmt.t option -> (string -> string option) -> t

val apply: t -> string -> string option

val (>>>): t -> t -> t
val (<|>): t -> t -> t

val accept: t
val reject: t

val all: t list -> t
val first: t list -> t
val invert: t -> t

val pp: t Fmt.t
val pp_rule: t Fmt.t

val to_string: t -> string
