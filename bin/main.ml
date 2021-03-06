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

let line_stream_of_channel ic = Stream.of_list [input_line ic]

let pp_peer =
  let string_of_ic ic =
    Unix.descr_of_in_channel ic
    |> Unix.getpeername
    |> function
    | ADDR_UNIX p -> Fmt.strf "unix:%s" p
    | ADDR_INET (h, p) -> Fmt.strf "%s:%d" (Unix.string_of_inet_addr h) p
  in Fmt.using string_of_ic Fmt.string

let handler rules_getter ic oc =
  Logs.debug (fun m -> m "Connection from %a" pp_peer ic);

  let stream = line_stream_of_channel ic in
  let ppf = Format.formatter_of_out_channel oc in
  Mapper.Server.serve ppf rules_getter stream;
  Logs.debug (fun m -> m "Client closed the connection.")

let main host port rules_file update_rules init _ =
  let rules_getter =
    if update_rules then
      begin
        Logs.debug (fun m -> m "Parsing rules for each request.");
        fun () -> extract_rules rules_file
      end
    else
      begin
        Logs.debug (fun m -> m "Parsing rules once.");
        let rules = extract_rules rules_file in
        fun () -> rules
      end
  in
  let bundle = Mapper.Server.Handler (rules_getter, Mapper.apply, Mapper.pp_rule) in
  Logs.info (fun m -> m "Establishing server at %s:%d." host port);
  let local_addr = Unix.ADDR_INET(Unix.inet_addr_of_string host, port) in
  let serve_forever _ = establish_server (handler bundle) local_addr in
  let status =
    if init then
      Mapper.Init.supervise serve_forever
    else
      begin
        serve_forever ();
        WEXITED 0
      end
  in
  match status with
  | WEXITED 0 ->
    (* regardless of init, we should never reach this point *)
    Logs.err @@ fun m -> m "Server unexpectedly stopped serving."
  | WEXITED n ->
    (* internal error? *)
    Logs.err @@ fun m -> m "Server process terminated with exit code %d." n
  | WSIGNALED s ->
    (* somebody forced the child to terminate, this is probably ok *)
    let s = Mapper.Init.string_of_signal s in
    Logs.info @@ fun m -> m "Server was killed by signal %s." s
  | WSTOPPED s ->
    (* this is probably not even possible *)
    let s = Mapper.Init.string_of_signal s in
    Logs.err @@ fun m -> m "Server was stopped by signal %s." s


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

let init_term =
  let doc = "Run as PID 1 (forward signals and reap zombies)." in
  Arg.(value & flag & info ["i"; "init"] ~doc)

let main_term = Term.(const main
                      $ host_term
                      $ port_term
                      $ rules_term
                      $ update_rules_term
                      $ init_term
                      $ log_term
                     )

let info =
  let doc = "Run a configurable address mapping server for postfix." in
  Term.info bin_name ~version:bin_version ~doc

let () = match Term.eval (main_term, info) with `Error _ -> exit 1 | _ -> exit 0
