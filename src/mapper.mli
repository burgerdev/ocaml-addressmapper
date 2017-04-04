
type t
val accept: t
val reject: t
val of_fun: (string -> string option) -> t

val all: t -> t -> t
val any: t -> t -> t

val traverse: string -> t -> string option
