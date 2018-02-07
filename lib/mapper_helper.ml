
module Fmt = struct
  include Fmt

  let (>>>) pp_a pp_b = suffix sp pp_a |> suffix pp_b

  let str s = Fmt.(const string s)

  let pp_ppu ppf ppu = ppu ppf ()

  let pp_of_pp_list pps = const (list ~sep:sp pp_ppu) pps

  let indent = 1

  let boxed_parens pp = hvbox ~indent pp |> parens

  let repeat n pp =
    let rec aux acc = function
      | n when n > 0 -> aux (suffix pp acc) (n - 1)
      | _ -> acc
    in aux nop n
end

module Option = struct
  include Ocat.Ocat_modules.Option

  let invert d = function
    | Some _ -> None
    | None -> Some d

  let (<|>) f g = fun input -> match f input with
    | None -> g input
    | some -> some

  let pp ppf = function
    | Some x -> Fmt.(const (fmt "Some(%s)") x) ppf ()
    | None -> Fmt.(const string "None") ppf ()
end

module Sexplib = struct
  include Sexplib

  module Fix = struct
    module S = struct
      type 'a t =
        | ListF of 'a list
        | AtomF of string
      let map f = function
        | AtomF s -> AtomF s
        | ListF subs -> ListF (List.map f subs)
    end
    include S
    include Ocat.Fix(S)
  end
end
