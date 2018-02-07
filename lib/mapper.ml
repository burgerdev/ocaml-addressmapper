open Sexplib
open Fmt

include Mapper_rule
include Mapper_predef
include Mapper_eval
include Mapper_io


module Server = Server
module Init = Init


type rule = unit fix

let accept = accept |> fix
let reject = reject |> fix
let lower = lower |> fix
let upper = upper |> fix

let constant s = constant s |> fix
let equals s = equals s |> fix
let matches s = matches s |> fix
let replace r s = replace r s |> fix
let prefix_matches p = prefix_matches p |> fix
let suffix_matches p = suffix_matches p |> fix
