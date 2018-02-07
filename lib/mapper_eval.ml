open Mapper_rule
open Mapper_alg
open Mapper_helper

let log_src = Logs.Src.create "mapper"

module Logs = (val (Logs.src_log log_src))

let comment pp input output =
  Logs.debug (fun m -> m "%a mapped %s to %a" pp () input Option.pp output)

let logging_rule_alg = fun a_rule ->
  let name = name_alg a_rule in
  let f = rule_alg a_rule in
  fun input ->
    let output = f input in
    comment name input output;
    output

let apply rule =
  let f = cata logging_rule_alg rule in
  fun input -> f input
