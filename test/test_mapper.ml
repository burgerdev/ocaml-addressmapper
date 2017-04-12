open OUnit
open Mapper

let test_string = "test"

let test_all _ =
  assert_equal (traverse test_string (all [accept; accept])) (Some(test_string));
  assert_equal (traverse test_string (all [reject; accept])) None;
  assert_equal (traverse test_string (all [accept; reject])) None;
  assert_equal (traverse test_string (all [reject; reject])) None

let test_first _ =
  assert_equal (traverse test_string (first [accept; accept])) (Some(test_string));
  assert_equal (traverse test_string (first [reject; accept])) (Some(test_string));
  assert_equal (traverse test_string (first [accept; reject])) (Some(test_string));
  assert_equal (traverse test_string (first [reject; reject])) None

let test_matches _ =
  assert_equal (traverse test_string (matches test_string)) (Some(test_string));
  assert_equal (traverse test_string (matches "es")) (Some(test_string));
  assert_equal (traverse test_string (matches "^es$")) None;
  assert_equal (traverse test_string (matches "^test$")) (Some(test_string));
  assert_equal (traverse test_string (matches ".*")) (Some(test_string))

let test_replace _ =
  let replacement = "foo" in
  assert_equal (traverse test_string (replace test_string replacement)) (Some(replacement));
  assert_equal (traverse test_string (replace "es" "")) (Some("tt"));
  assert_equal (traverse test_string (replace  "^es$" replacement)) (Some(test_string));
  assert_equal (traverse test_string (replace "^test$" replacement)) (Some(replacement));
  assert_equal (traverse test_string (replace ".*" replacement)) (Some(replacement))

let test_sexp _ =
  let a = all [(first [matches "a"; reject]); accept; replace "a" "b"] in
  let s = sexp_of_t a in
  let b = t_of_sexp s in
  assert_equal a b

let test_sexp_string _ =
  let a = all [(first [matches "a"; reject]); accept; replace "(.*\")" "b"] in
  let s = Sexplib.Sexp.to_string (sexp_of_t a) in
  let b = t_of_sexp (Sexplib.Sexp.of_string s) in
  assert_equal a b

let suite =
  "mapper suite" >::: ["test_all" >:: test_all;
                       "test_first" >:: test_first;
                       "test_sexp" >:: test_sexp;
                       "test_sexp_string" >:: test_sexp_string;
                       "test_matches" >:: test_matches;
                       "test_replace" >:: test_replace]

let _ =
  run_test_tt_main suite
