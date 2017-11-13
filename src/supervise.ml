open Unix

let bin_name = "supervise"
let bin_version = "0.8"

let main prog argv _ =
  let child _ =
    execv prog (Array.of_list argv)
  in
  match argv with
  | [] ->
    Logs.err (fun m -> m "Empty argument vector not allowed!");
    exit 1
  | _ :: t ->
    let log_args _ =
      let quoted = List.map (fun s -> Printf.sprintf "'%s'" s) t in
      String.concat " " (prog :: quoted)
    in Logs.debug
      (fun m -> m "Supervising effective command line: [%s]" (log_args ()));
    Init.supervise child

(* Logging stuff, copy pasta from docs *)

let setup_log style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

(* Cmdliner stuff *)

open Cmdliner

let log_term =
  Term.(const setup_log $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let prog_term =
  let doc = "Program to execute (is looked up in PATH)" in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"PROGRAM" ~doc)

let args_term =
  let doc = "Program arguments. The first argument should be the program's name (argv[0])." in
  Arg.(non_empty & pos_right 0 string [] & info [] ~docv:"ARG" ~doc)

let main_term = Term.(const main $ prog_term $ args_term $ log_term)

let info_term =
  let doc = "Supervise a process like a real init process would." in
  Term.info bin_name ~version:bin_version ~doc

let () =
  let code = match Term.eval (main_term, info_term) with
  | `Ok (WEXITED n) -> n
  | `Ok (_) -> 255
  | res -> Term.exit_status_of_result res in
  exit code
