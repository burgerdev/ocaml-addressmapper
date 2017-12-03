type rule =
  | Combination of combination
  | Terminal of terminal
and combination =
  | All of rule list
  | First of rule list
  | And of rule * rule
  | Or of rule * rule
  | Not of rule
and terminal =
  | Accept | Reject | Lower | Upper
  | Equals of string
  | Matches of string
  | Replace of string * string
  | Constant of string
  | Prefix of string
  | Suffix of string
