open Mapper_rule
open Mapper_alg

let rule_of_sexp sexp = ana sexp_coalg sexp

let pp_rule ppf r = cata pp_alg r ppf ()

let pp = pp_rule

(* TODO *)
let sexp_of_rule rule = cata sexp_alg rule
