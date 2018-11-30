open Unix

let bin_name = "address-mapping-server"
let bin_version = "0.9"

let extract_rules filename_opt =
  match filename_opt with
  | None -> Mapper.accept
  | Some filename ->
    let ic = open_in filename in
    let s = Sexplib.Sexp.input_sexp ic in
    Mapper.Parser.rule_of_sexp s

let wait_for_signal x =
  let open Lwt in
  let (t, u) = Lwt.task () in
  ignore (Lwt_unix.on_signal Sys.sigint (fun _ -> Lwt.wakeup_later u ()));
  ignore (Lwt_unix.on_signal Sys.sigterm (fun _ -> Lwt.wakeup_later u ()));
  t >|= fun _ -> x

let main host port rules_file _update_rules _ =
  let open Lwt in
  let rule = extract_rules rules_file in
  let local_addr = Unix.ADDR_INET(Unix.inet_addr_of_string host, port) in
  let main_thread =
    Mapper.Mapper_lwt.handle rule
    |> Lwt_io.establish_server_with_client_address local_addr
    >>= wait_for_signal
    >>= Lwt_io.shutdown_server
  in Lwt_main.run main_thread


(* Logging stuff, copy pasta from docs *)

let setup_log style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

(* Command line interface *)

open Cmdliner

let log_term =
  Term.(const setup_log $ Fmt_cli.style_renderer () $ Logs_cli.level ())

(* Cmdliner stuff *)

let host_term =
  let doc = "Bind address to listen on." in
  Arg.(value & opt string "127.0.0.1" & info ["b"; "bind"] ~docv:"BIND-ADDRESS" ~doc)

let port_term =
  let doc = "TCP port to listen on." in
  Arg.(value & opt int 30303 & info ["p"; "port"] ~docv:"PORT" ~doc)

let rules_term =
  let doc = "File containing mapping rules. Consult the repository documentation for details." in
  Arg.(value & opt (some string) None & info ["r"; "rules"] ~docv:"RULES-FILE" ~doc)

let update_rules_term =
  let doc = "Read rules file for every request." in
  Arg.(value & flag & info ["u"; "update"] ~doc)

let main_term = Term.(const main
                      $ host_term
                      $ port_term
                      $ rules_term
                      $ update_rules_term
                      $ log_term
                     )

let info =
  let doc = "Run a configurable address mapping server for postfix." in
  Term.info bin_name ~version:bin_version ~doc

let () = match Term.eval (main_term, info) with `Error _ -> exit 1 | _ -> exit 0
