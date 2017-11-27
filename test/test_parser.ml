open OUnit
open Mapper

let all_rules =
  "(first ((
            (first (accept reject))
            (not (matches \"foo\"))
            (replace \"bar\" \"baz\")
            ( (() && (prefix_matches \"ba\")) && (suffix_matches \"az\"))
            ((first ()) || (replace \"baz\" \"foo\"))
           )
           (replace \".*\" \"moo\")
           (first (
                   (equals \"foo\")
                   (equals \"moo\")
           ))
          )
   )"

let test_sexp_string _ =
  let rule = rule_of_sexp (Sexplib.Sexp.of_string all_rules) in
  assert_equal (Mapper.apply rule "bar") (Some "foo");
  assert_equal (Mapper.apply rule "foo") (Some "moo")

let test_documentation _ =
  let rules =
    "
(
  (lower (replace \"+[^@]*@\" \"@\"))

  (not (prefix_matches \"sauron\"))

  (first
    (
      (
        (matches \"^[^@]+@business\\.com$\")
        (first ((matches \"^ceo@.*\")
                (matches \"^pr@.*\"))
        )
      )
      (equals \"donations@nonprofit.org\")
    )
  )
)
    " in
  let rule = rule_of_sexp (Sexplib.Sexp.of_string rules) in
  let verify input output =
    assert_equal output (Mapper.apply rule input) in
  verify "sauron@mord.or" None;
  verify "sauron+saruman@mord.or" None;
  verify "ceo@business.com" (Some "ceo@business.com");
  verify "ceo+private@business.com" (Some "ceo@business.com");
  verify "pr@business.com" (Some "pr@business.com");
  verify "pr+ap@business.com" (Some "pr@business.com");
  verify "donations@nonprofit.org" (Some "donations@nonprofit.org");
  (* subtle edge cases *)
  verify "donations@nonprofitDorg" None;
  verify "ceo@hacked@business.com" None;
  (* documented examples *)
  verify "CEO@business.COM" (Some "ceo@business.com");
  verify "donations+fundraiser2017@nonprofit.org" (Some "donations@nonprofit.org")

let test_inverse_regressions _ =
  [ ("(first (accept))", first [accept])
  ; ("accept", accept)
  ; ("((first ()))", all [first []])
  ]
  |> List.iter @@ function (expected, input) ->
    let actual = Fmt.strf "%a" dump input in
    if expected <> actual then
      Fmt.failwith "%s <> %s" expected actual

let test_inverse _ =
  let rule = Sexplib.Sexp.of_string all_rules |> rule_of_sexp in
  let rule' = sexp_of_rule rule |> rule_of_sexp in
  if rule <> rule' then
    let s1 =
      Sexplib.Sexp.of_string all_rules
      |> Sexplib.Sexp.to_string_hum in
    let s2 =
      sexp_of_rule rule
      |> Sexplib.Sexp.to_string_hum in
    Fmt.failwith "sexp <-> rule conversion is not bijective:@[<v>@,@[<hov>%s@]@,<>@,@[<hov>%s@]" s1 s2

let suite =
  "mapper suite" >::: [ "test_sexp_string" >:: test_sexp_string
                      ; "test_documentation" >:: test_documentation
                      ; "test_inverse" >:: test_inverse
                      ; "test_inverse_regressions" >:: test_inverse_regressions
                      ]

let _ =
  run_test_tt_main suite
