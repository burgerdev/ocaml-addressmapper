open Sexplib
open Fmt

include Mapper_rule
include Mapper_exec


module Parser = Mapper_parser
module Server = Server
module Init = Init

type t = rule

let log_src = Logs.Src.create "mapper"

let accept = Terminal Accept

let reject = Terminal Reject

let all rules = Combination (All rules)

let first rules = Combination (First rules)

let not rule = Combination (Not rule)

let matches pattern = Terminal (Matches pattern)

let equals other = Terminal (Equals other)

let replace pattern replacement = Terminal (Replace (pattern, replacement))

let prefix_matches prefix = Terminal (Prefix prefix)

let suffix_matches suffix = Terminal (Suffix suffix)

let lower = Terminal Lower

let upper = Terminal Upper

let constant c = Terminal (Constant c)

let apply rule input =
  fun_of_rule rule input
