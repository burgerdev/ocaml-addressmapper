open Unix
open Server

let bin_name = "address-mapping-server"
let bin_version = "0.7"

let extract_rules filename_opt =
  match filename_opt with
  | None -> Mapper.accept
  | Some filename ->
    let ic = open_in filename in
    let s = Sexplib.Sexp.input_sexp ic in
    Parser.rule_of_sexp s

let handler rules_getter ic oc =
  let rec handle_single_request _ =
    let response =
      let input = input_line ic in
      match request_of_string input with
      | Invalid a ->
        Logs.warn (fun m -> m "Malformed request [%s]" a);
        Malformed
      | Get a ->
        begin
          try
            match Mapper.apply (rules_getter ()) a with
            | Some b ->
              Logs.info (fun m -> m "Found mapping of [%s] to [%s]." a b);
              Found b
            | None ->
              Logs.info (fun m -> m "No mapping found for [%s]." a);
              Not_found
          with
          | e ->
            Logs.err (fun m -> m "Internal error.");
            Internal_error e
        end
      | Put a ->
        Logs.warn (fun m -> m "Unsupported put request [%s]" a);
        Unsupported
      | Health ->
        try
          ignore (rules_getter ());
          Health Rules_ok
        with
        | _ ->
          Logs.err (fun m -> m "Internal error.");
          Health Rules_error

    in
    output_string oc (string_of_response response);
    flush oc;
    match response with
    | Internal_error e -> raise e
    | _ -> handle_single_request ()
  in
  try
    handle_single_request ()
  with
  | End_of_file ->
    Logs.info (fun m -> m "Client closed the connection.")

let main host port rules_file update_rules _ =
  let rules_getter =
    if update_rules then
      begin
        Logs.debug (fun m -> m "Parsing rules for each request.");
        let f () = extract_rules rules_file in f
      end
    else
      begin
        Logs.debug (fun m -> m "Parsing rules once.");
        let rules = extract_rules rules_file in
        let f () = rules in f
      end
  in
  Logs.app (fun m -> m "Establishing server at %s:%d." host port);
  let local_addr = Unix.ADDR_INET(Unix.inet_addr_of_string host, port) in
  let serve_forever _ = establish_server (handler rules_getter) local_addr in
  Init.supervise serve_forever

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
