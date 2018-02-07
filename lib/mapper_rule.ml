
open Ocat


type f = string -> string option
type terminal = unit Fmt.t * f

module R = struct
  type 'a t =
    | All of 'a list
    | First of 'a list
    | Not of 'a
    | Terminal of terminal

  let map f = function
    | All rules -> All (List.map f rules)
    | First rules -> First (List.map f rules)
    | Not rule -> Not (f rule)
    | Terminal f -> Terminal f
end

include R
include Functor(R)
include Fix(R)

let all rules = All rules |> fix
let first rules = First rules |> fix
let invert rule = Not rule |> fix
let terminal label rule = Terminal (label, rule) |> fix
let terminal_str s rule = Terminal (Fmt.(const string s), rule) |> fix
