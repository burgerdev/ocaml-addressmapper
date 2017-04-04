open OUnit
open Mapper

let test_string = "test"

let test_all _ =
  assert_equal (traverse test_string (all accept accept)) (Some(test_string));
  assert_equal (traverse test_string (all reject accept)) None;
  assert_equal (traverse test_string (all accept reject)) None;
  assert_equal (traverse test_string (all reject reject)) None

let test_any _ =
  assert_equal (traverse test_string (any accept accept)) (Some(test_string));
  assert_equal (traverse test_string (any reject accept)) (Some(test_string));
  assert_equal (traverse test_string (any accept reject)) (Some(test_string));
  assert_equal (traverse test_string (any reject reject)) None

let suite =
  "mapper suite" >::: ["test_all" >:: test_all;
                       "test_any" >:: test_any]

let _ =
  run_test_tt_main suite
