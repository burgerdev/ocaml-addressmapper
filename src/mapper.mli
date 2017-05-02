
open Sexplib

type t

val accept: t
val reject: t

val lower: t
val upper: t

val all: t list -> t
val first: t list -> t

val matches: string -> t
val replace: string -> string -> t

val traverse: string -> t -> string option

val sexp_of_t: t -> Sexp.t
val t_of_sexp: Sexp.t -> t
