open Unix
open Cmdliner

let bin_name = "address-mapping-server"
let bin_version = "0.1"

let logc = out_channel_of_descr stderr

let extract_rules f =
  (* TODO *)
  Mapper.accept

let parse_email s =
  try
    Scanf.sscanf s "get %s" (fun x -> Some x)
  with
  | Scanf.Scan_failure(_) -> None

type status =
  | Malformed
  | Not_found
  | Error
  | Found of string

let message_of_status s =
  match s with
  | Malformed -> "400 malformed request\n"
  | Error -> "500 internal server error\n"
  | Not_found -> "500 not-found\n"
  | Found s -> Format.sprintf "200 %s\n" s

let handler rules ic oc =
  let s =
    try
      let input = input_line ic in
      let email = parse_email input in
      match email with
      | None ->
        Printf.fprintf logc "Error: malformed request [%s]\n" input;
        Malformed
      | Some a ->
        match Mapper.traverse a rules with
        | Some b ->
          Printf.fprintf logc "Info: found mapping of [%s] to [%s].\n" a b;
          Found b
        | None ->
          Printf.fprintf logc "Info: no mapping found for [%s].\n" a;
          Not_found
    with
    | End_of_file ->
      Printf.fprintf logc "Error: EOF encountered while scanning.\n";
      Malformed in
  output_string oc (message_of_status s)

let main host port rules_file =
  Printf.printf "Establishing connection at %s:%d.\n" host port;
  let local_addr = Unix.ADDR_INET(Unix.inet_addr_of_string "127.0.0.1", port) in
  establish_server (handler (extract_rules rules_file)) local_addr


(* Cmdliner stuff *)

let host_term =
  let doc = "Bind address to listen on." in
  Arg.(value & opt string "127.0.0.1" & info ["b"; "bind"] ~docv:"BIND-ADDRESS" ~doc)

let port_term =
  let doc = "TCP port to listen on." in
  Arg.(value & opt int 30303 & info ["p"; "port"] ~docv:"PORT" ~doc)

let rules_term =
  let doc = "File containing mapping rules [NOT IMPLEMENTED]." in
  Arg.(value & opt (some string) None & info ["r"; "rules"] ~docv:"RULES-FILE" ~doc)

let main_term = Term.(const main $ host_term $ port_term $ rules_term)

let info =
  let doc = "Run a configurable address mapping server for postfix." in
  Term.info bin_name ~version:bin_version ~doc

let () = match Term.eval (main_term, info) with `Error _ -> exit 1 | _ -> exit 0
