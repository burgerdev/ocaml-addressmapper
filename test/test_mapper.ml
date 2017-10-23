open OUnit
open Mapper

let test_string = "test"

let apply_test r = apply r test_string

let test_all _ =
  assert_equal (apply_test (all [accept; accept])) (Some(test_string));
  assert_equal (apply_test (all [reject; accept])) None;
  assert_equal (apply_test (all [accept; reject])) None;
  assert_equal (apply_test (all [])) (Some(test_string));
  assert_equal (apply_test (all [reject; reject])) None

let test_first _ =
  assert_equal (apply_test (first [accept; accept])) (Some(test_string));
  assert_equal (apply_test (first [reject; accept])) (Some(test_string));
  assert_equal (apply_test (first [accept; reject])) (Some(test_string));
  assert_equal (apply_test (first [reject; reject])) None;
  assert_equal (apply_test (first [])) None

let test_not _ =
  assert_equal (apply_test (not accept)) (None);
  assert_equal (apply_test (not reject)) (Some(test_string));
  assert_equal (apply_test (not (all [accept; reject]))) (Some(test_string));
  assert_equal (apply_test (not (first [accept; reject]))) None;
  assert_equal (apply_test (not (matches test_string))) None;
  assert_equal (apply_test (not (not (matches test_string)))) (Some(test_string))

let test_matches _ =
  assert_equal (apply_test  (matches test_string)) (Some(test_string));
  assert_equal (apply_test  (matches "es")) (Some(test_string));
  assert_equal (apply_test  (matches "^es$")) None;
  assert_equal (apply_test  (matches "^test$")) (Some(test_string));
  assert_equal (apply_test  (matches ".*")) (Some(test_string))

let test_replace _ =
  let replacement = "foo" in
  assert_equal (apply_test  (replace test_string replacement)) (Some(replacement));
  assert_equal (apply_test  (replace "es" "")) (Some("tt"));
  assert_equal (apply_test  (replace  "^es$" replacement)) (Some(test_string));
  assert_equal (apply_test  (replace "^test$" replacement)) (Some(replacement));
  assert_equal (apply_test  (replace ".*" replacement)) (Some(replacement))

let test_case _ =
  let a, biga = "a", "A" in
  assert_equal (apply upper a) (Some(biga));
  assert_equal (apply lower biga) (Some(a))

let suite =
  "mapper suite" >::: [ "test_all" >:: test_all
                      ; "test_first" >:: test_first
                      ; "test_not" >:: test_not
                      ; "test_case" >:: test_case
                      ; "test_matches" >:: test_matches
                      ; "test_replace" >:: test_replace
                      ]

let _ =
  run_test_tt_main suite
