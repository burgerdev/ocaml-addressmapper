open OUnit
open Server

let must_match pattern = function
  | x when pattern = x -> ()
  | x -> failwith ("did not match [" ^ (string_of_request x) ^ "]")

let test_parse _ =
  must_match (Get "abuse@example.com") (request_of_string "get abuse@example.com");
  must_match (Get "abuse 1example.com") (request_of_string "get a%62use%201example.com");
  must_match (Put "abuse@example.com") (request_of_string "put abuse@example.com");
  must_match Health (request_of_string "health");
  must_match (Invalid "something else") (request_of_string "something else")

let suite =
  "mapper suite" >::: [ "test_parse" >:: test_parse
                      ]

let _ =
  run_test_tt_main suite
