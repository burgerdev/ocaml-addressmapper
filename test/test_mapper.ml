open OUnit
open Mapper

let test_string = "test"
let test_string_dot = "test.string"

let apply_test r = apply r test_string

let pp_opt = function
  | Some x -> Format.sprintf "Some(%s)" x
  | None -> Format.sprintf "None"

let assert_equal expected actual =
  let msg = Format.sprintf "expected [%s], actual [%s]" (pp_opt expected) (pp_opt actual) in
  match (expected, actual) with
  | None, None -> ()
  | Some a, Some b when String.compare a b == 0 -> ()
  | _ -> failwith msg

let must_transform ?input_string:(input_string=test_string) output_string rule =
  assert_equal (Some output_string) (apply rule input_string)

let must_accept ?input_string:(input_string=test_string) rule =
  must_transform input_string ~input_string:input_string rule

let must_reject ?input_string:(input_string=test_string) rule =
  assert_equal None (apply rule input_string)

let test_all _ =
  must_accept (all [accept; accept]);
  must_reject (all [reject; accept]);
  must_reject (all [accept; reject]);
  must_reject (all [reject; reject]);
  must_accept (all [])

let test_first _ =
  must_accept (first [accept; accept]);
  must_accept (first [reject; accept]);
  must_accept (first [accept; reject]);
  must_reject (first [reject; reject]);
  must_reject (first [])

let test_invert _ =
  must_reject (invert accept);
  must_accept (invert reject);
  must_accept (invert (all [accept; reject]));
  must_reject (invert (first [accept; reject]));
  must_reject (invert (matches test_string));
  must_accept (invert (invert (matches test_string)))

let test_matches _ =
  must_accept (matches test_string);
  must_accept (matches "es");
  must_reject (matches "^es$");
  must_accept (matches "^test$");
  must_accept (matches ".*");

  let must_reject = must_reject ~input_string:test_string_dot in
  let must_accept = must_accept ~input_string:test_string_dot in
  must_accept (prefix_matches test_string_dot);
  must_accept (prefix_matches "test.s");
  must_reject (prefix_matches "testos");
  must_accept (suffix_matches test_string_dot);
  must_accept (suffix_matches "t.string");
  must_reject (suffix_matches "tostring")

let test_replace _ =
  let replacement = "foo" in
  must_transform replacement (replace test_string replacement);
  must_transform "tt" (replace "es" "");
  must_transform test_string (replace  "^es$" replacement);
  must_transform replacement (replace "^test$" replacement);
  must_transform replacement (replace ".*" replacement)

let test_case _ =
  let a, biga = "a", "A" in
  must_transform ~input_string:a biga upper;
  must_transform ~input_string:biga biga upper;
  must_transform ~input_string:a a lower;
  must_transform ~input_string:biga a lower

let suite =
  "mapper suite" >::: [ "test_all" >:: test_all
                      ; "test_first" >:: test_first
                      ; "test_not" >:: test_invert
                      ; "test_case" >:: test_case
                      ; "test_matches" >:: test_matches
                      ; "test_replace" >:: test_replace
                      ]

let _ =
  run_test_tt_main suite
