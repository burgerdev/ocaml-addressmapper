
module Option = struct
  let bind f = function
    | None -> None
    | Some x -> f x

  let return x = Some x

  let (>>=) x f = bind f x
  let map f x = x >>= fun a -> Some (f a)

  let (>=>) f g = fun x -> f x >>= g

  let default d = function
    | Some x -> x
    | None -> d
end

type label = unit Fmt.t
type t = Rule of label option * (string -> string option)
type rule = t

let label = function
  | Rule (pp, _) -> pp

let map_label f = function
  | Rule (label, mapper) -> Rule (f label, mapper)

let pp = fun ppf rule -> Option.(default Fmt.nop (label rule)) ppf ()

let pp_rule = pp

let to_string rule = Fmt.strf "%a" pp rule

let create_pp pp mapper = Rule (pp, mapper)

let create name mapper = create_pp (Some Fmt.(const string name)) mapper

let apply = function
  | Rule (_, f) -> f

let (|+|) pp_opt pp_opt' = match (pp_opt, pp_opt') with
  | (Some pp, Some pp') -> Some Fmt.(prefix sp pp' |> prefix pp)
  | (None, Some pp) | (Some pp, None) -> Some pp
  | (None, None) -> None

let boxed pp = Fmt.(hvbox ~indent:1 pp |> parens)

let boxed_opt pp_opt = Option.(default Fmt.nop pp_opt |> boxed |> return)

let (>>>) r r' =
  Rule (label r |+| label r', Option.(apply r >=> apply r'))

let (<|>) r r' =
  let g input = match apply r input with
    | None -> apply r' input
    | some -> some in
  Rule (label r |+| label r', g)

let without_label = map_label @@ fun _ -> None

let accept = create "accept" Option.return

let reject = create "reject" @@ fun _ -> None

let all rules =
  List.fold_left (>>>) (without_label accept) rules
  |> map_label boxed_opt

let first rules =
  List.fold_left (<|>) (without_label reject) rules
  |> map_label boxed_opt
  |> map_label @@ Option.map Fmt.(prefix @@ const string "first ")
  |> map_label boxed_opt

let invert rule =
  let f = apply rule in
  let f' input = match f input with None -> Some input | _ -> None in
  let label' =
    Fmt.(
      label rule
      |> Option.map @@ prefix @@ const string "not "
      |> Option.map boxed)
  in
  Rule (label', f')
