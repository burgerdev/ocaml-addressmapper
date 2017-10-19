open Unix
open Cmdliner

let bin_name = "supervise"
let bin_version = "0.6"

let logc = out_channel_of_descr stderr

let logNow s =
  Printf.fprintf logc "[%d] %s\n" (getpid ()) s; flush logc


let main c use_demo prog argv =
  let rec child _ =
    if use_demo then
      begin
        logNow "forking";
        match fork () with
        | 0 ->
          begin
            logNow "double forking";
            match fork () with
            | 0 ->
              sleep 1;
              logNow "grandchild exec";
              execv prog (Array.of_list argv)
            | _ ->
              logNow "child exit";
              exit 2
          end
        | i ->
          (* parent process keeps spawning children *)
          logNow (Printf.sprintf "forked process %d" i);
          let rec aux _ =
            try
              ignore (waitpid [] i)
            with
            | Unix_error (EINTR, _, _) -> aux ()
          in aux ();
          sleep 5;
          child ()
      end
    else
      execv prog (Array.of_list argv)
  in
  match argv with
  | [] ->
    Printf.fprintf logc "Empty argument vector not allowed!";
    1
  | _ :: t ->
    Printf.fprintf logc "Supervising effective command line: [%s" prog;
    (* supervise_exec prog args *)
    let rec aux = function
      | [] ->
        Printf.fprintf logc "].\n";
        flush logc;
        Init.supervise ~cleanup:c child
      | h :: t ->
        Printf.fprintf logc " '%s'" h;
        aux t
    in aux t


(* Cmdliner stuff *)

let cleanup_parser = function
  | "g" -> Ok Init.Kill_group
  | "p" -> Ok Init.Kill_parent_group
  | s ->
    (* TODO proper error handling *)
    try
      Ok (Init.Kill_pid (int_of_string s))
    with _ -> Error (`Msg "Invalid pid.")

let cleanup_printer (ppf: Format.formatter) = function
  | Init.Kill_group -> Format.fprintf ppf "g"
  | Init.Kill_parent_group -> Format.fprintf ppf "p"
  | Init.Kill_pid pid -> Format.fprintf ppf "%d" pid

let cleanup_conv = Arg.conv (cleanup_parser, cleanup_printer)

let cleanup_term =
  let doc = "PID to clean up after main child terminated. 'g' cleans up the childs group, 'p' the supervisors group." in
  Arg.(value & opt (some cleanup_conv) None & info ["c"; "cleanup"] ~doc)

let demo_term =
  let doc = "Use demo app." in
  Arg.(value & flag & info ["d"; "demo"] ~doc)

let prog_term =
  let doc = "Program to execute (is looked up in PATH)" in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"PROGRAM" ~doc)

let args_term =
  let doc = "Program arguments. The first argument should be the program's name (argv[0])." in
  Arg.(non_empty & pos_right 0 string [] & info [] ~docv:"ARG" ~doc)

let main_term = Term.(const main $ cleanup_term$ demo_term $ prog_term $ args_term)

let info_term =
  let doc = "Supervise a process like a real init process would." in
  Term.info bin_name ~version:bin_version ~doc

let () =
  let code = match Term.eval (main_term, info_term) with
  | `Ok n -> n
  | res -> Term.exit_status_of_result res in
  exit code