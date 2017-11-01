
open Sexplib

val rule_of_sexp: Sexp.t -> Mapper.rule
(* [rule_of_sexp s] parses [s] according to the documented grammar *)
