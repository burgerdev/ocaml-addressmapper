
type leaf = string -> string option

type mapping =
  | And of mapping * mapping
  | Or of mapping * mapping
  | Leaf of leaf

type t = mapping

let all a b = And(a, b)
let any a b = Or(a, b)

let of_fun f = Leaf f

let accept = Leaf (fun s -> Some s)
let reject = Leaf (fun _ -> None)

let rec traverse s tree =
  match tree with
  | Leaf f -> f s
  | And(l, r) ->
    begin
      match traverse s l with
      | Some s1 -> traverse s1 r
      | None -> None
    end
  | Or(l, r) ->
    begin
      match traverse s l with
      | Some s1 -> Some s1
      | None -> traverse s r
    end
