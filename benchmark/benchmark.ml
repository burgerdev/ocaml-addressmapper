open Core_bench.Std
open Unix

let line_stream_of_channel ic = Stream.of_list [input_line ic]

let local_addr = Unix.ADDR_INET(Unix.inet_addr_of_string "127.0.0.1", 30305)

let single_request query = fun () ->
  let (ic, oc) = open_connection local_addr in
  output_string oc query;
  flush oc;
  let line = input_line ic in
  close_out oc;
  line


let handler rules_getter ic oc =
  let stream = line_stream_of_channel ic in
  let ppf = Format.formatter_of_out_channel oc in
  Mapper.Server.serve ppf rules_getter stream

let serve_forever =
  let rule_string = "(\
                     (first (\
                     (matches \"^ab\")\
                     (matches \"yz$\")\
                     reject\
                     ))\
                     (replace \"a\" \"b\")\
                     accept\
                     (replace \"[0-9]+\" \"NUMBERS\"))" in
  let rules_getter () = Sexplib.Sexp.of_string rule_string |> Mapper.Parser.rule_of_sexp in
  let bundle = Mapper.Server.Handler (rules_getter, Mapper.apply, Mapper.pp_rule) in
  fun () -> establish_server (handler bundle) local_addr

let start_server () = match fork () with
  | 0 ->
    serve_forever (); 0
  | pid ->
    sleep 1;
    pid

let test_string () =
  (* plausible email address length *)
  let length = 25 in
  String.make length (Random.int 128 + 1 |> char_of_int)

let benchmark_rule rule =
  let ts = test_string () in
  let f () = Mapper.apply rule ts |> ignore in
  Bench.Test.create ~name:(Fmt.strf "%a" Mapper.pp_rule rule) f

let benchmark_remote req =
  let ts = req ^ "\n" in
  let f () = single_request ts () |> ignore in
  Bench.Test.create ~name:("remote " ^ req) f

let rules = Mapper.[accept;
                    replace ".{,4}(.{,5})(.*)" "\\1\\2";
                    prefix_matches "a";
                    suffix_matches "a";
                    matches ".*foo"]

let benchmarks =
  benchmark_remote "get --N/A--" ::
  benchmark_remote "get a123456789yz" ::
  benchmark_remote "health" ::
  benchmark_remote "put foobar" :: 
  []
(* List.map benchmark_rule rules *)

let finally_kill pid f =
  try
    f ();
    kill pid Sys.sigterm
  with
  | e ->
    kill pid Sys.sigterm;
    raise e

let main () =
  Random.self_init ();
  Core.Command.run (Bench.make_command benchmarks)

(* let () =
   let server_pid = start_server () in
   finally_kill server_pid main *)

let _ = main ()
