open OUnit
open Unix
open Sys
open Init

let range a b =
  let rec aux m n acc =
    if m < n then
      let next = n - 1 in
      aux m next (next :: acc)
    else
      acc
  in aux a b []

let status_codes = range 0 255

let kill_signals = [sigint; sigterm; sigkill; sigsegv; sigabrt; sigfpe; sighup]

let f_ret_normal status_code _ =
  exit status_code

let f_ret_sig signo _ =
  set_signal signo Signal_default;
  sleep 1;
  Printf.printf "me: %d, p: %d\n" (getpid ()) (getppid ());
  kill (getpid ()) sigterm;
  exit 1 (* should not happen! *)

let test_ret_normal _ =
  Printf.printf "test_ret_normal: %d, p: %d\n" (getpid ()) (getppid ());
  let assert_equal_status status_code =
    assert_equal (WEXITED status_code) (supervise (f_ret_normal status_code))
  in List.iter assert_equal_status status_codes

let test_ret_sig _ =
  Printf.printf "test_ret_sig: %d, p: %d\n" (getpid ()) (getppid ());
  let assert_signal_status signo =
    assert_equal (WSIGNALED signo) (supervise (f_ret_sig signo))
  in List.iter assert_signal_status kill_signals

let test_cleanup_pid _ = ()

let suite =
  "init suite" >::: [ "test_ret_normal" >:: test_ret_normal
                    (* does not work with OUnit ; "test_ret_sig" >:: test_ret_sig *)
                    (* not implemented ; "test_cleanup_pid" >:: test_cleanup_pid *)
                    ]

let _ =
   run_test_tt_main suite
