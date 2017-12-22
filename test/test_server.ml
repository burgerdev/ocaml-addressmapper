open OUnit
open Mapper.Server
open Fmt

let test_parse _ =
  let must_match (x, y) =
    if x <> request_of_string y then
      let pp_res ppf = function
        | Ok req -> pf ppf "Ok (%a)" pp_request req
        | Error s -> pf ppf "Error (%s)" s in
      failwith "did not match: @[<v>@[<hv>%a@]@,<>@,@[<hv>%a@]@]" pp_res x pp_res (request_of_string y)
    else
      ()
  in
  [ (Ok (Get "abuse@example.com"), "get abuse@example.com")
  ; (Ok (Get "a~use 1example\n.com"), "get a%7euse%201example%0A.com")
    ; (Ok (Put "abuse@example.com"), "put abuse@example.com")
  ; (Ok Health, "health")
  ; (Error "something else", "something else")
  ]
  |> List.iter @@ must_match

let test_format _ =
  let must_match (x, y) =
    let y = strf "%a" pp_response y in
    if x <> y then
      failwith "did not match: @[<v>@[<hv>%a@]@,<>@,@[<hv>%a@]@]" lines x lines y
    else
      ()
  in
  [ ("200 ok", Healthy)
  ; ("400 not ok", Unhealthy)
  ; ("400 internal server error", Internal_error)
  ; ("500 malformed request", Malformed)
  ; ("500 not found", Not_found)
  ; ("500 not implemented", Unsupported)
  ; ("200 asdf", Found "asdf")
  ; ("200 a~use%201example%0A.com", Found "a~use 1example\n.com")
  ]
  |> List.iter @@ must_match

let test_serve _ =
  let handler = Handler ((fun _ -> Mapper.accept), Mapper.apply, Mapper.pp_rule) in
  let (expected, input) =
    (List.fold_left @@ fun (a, b) (x, y) -> ("\n" :: x :: a, y :: b)) ([], []) @@
    [ ("200 abuse@example.com", "get abuse@example.com")
    ; ("200 a~use%201example%0A.com", "get a%7euse%201example%0A.com")
    ; ("500 not implemented", "put abuse@example.com")
    ; ("200 ok", "health")
    ; ("500 malformed request", "something else")
    ]
  in
  let expected =
    List.rev expected
    |> strf "%a" @@ list ~sep:nop string
  in
  List.rev input
  |> Stream.of_list
  |> (serve Format.str_formatter handler);
  let actual = Format.flush_str_formatter () in
  if expected <> actual then
    failwith "@[<v>@[<hv>%a@]@,<>@,@[<hv>%a@]@]" lines expected lines actual



let suite =
  "mapper suite" >::: [ "test_parse" >:: test_parse
                      ; "test_format" >:: test_format
                      ; "test_serve" >:: test_serve
                      ]

let _ =
  run_test_tt_main suite
