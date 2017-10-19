open Unix
open Sys

type cleanup =
  | Kill_group
  | Kill_parent_group
  | Kill_pid of int

let logc = out_channel_of_descr stderr

let logValue v =
  output_value logc v;
  output_string logc "\n";
  flush logc

let logWith level msg =
  output_string logc level;
  output_string logc ": ";
  output_string logc msg;
  output_string logc "\n";
  flush logc

let logError msg =
  logWith "Error" msg

let logInfo msg =
  logWith "Info" msg

(* TODO implement safe signalling (catch ESRCH) *)
let safe_kill pid signo =
  try
    kill pid signo
  with
  | Unix_error (ESRCH, _, _) ->
    (* child does not exist anymore, ignore *)
    ()

let graceful_kill whom () =
  (* start with issuing SIGTERM (we might be a recipient, so ignore) *)
  set_signal sigterm Signal_ignore;
  safe_kill whom sigterm;

  (* SIGKILL after grace period *)
  let on_alarm _ =
    try
      logError "Could not kill all children.";
      safe_kill whom sigkill;
      (* TODO if we were not part of the killed processes *)
      (* safe_kill 0 sigkill ??? *)
    with
    | _ ->
      (* ignore cleanup errors *)
      logError "More errors occured during cleanup.";
      ()
  in set_signal sigalrm (Signal_handle on_alarm);

  (* schedule SIGKILL *)
  ignore (alarm 5);

  (* keep reaping while the countdown is running *)
  let rec aux _ =
    try
      ignore (wait ())
    with
    | Unix_error (ECHILD, _, _) ->
      (* all children dead, abort kill and return normally *)
      set_signal sigalrm Signal_ignore
    | Unix_error (EINTR, _, _) -> aux ()
  in aux ()

(* wait for any child to terminate, exit if process 'n' *)
let rec supervise_pid cleanup n =
  try
    match wait () with
    | (m, cause) when m = n ->
      begin
        match cause with
        | WEXITED status_code ->
          logInfo (Printf.sprintf "Child exited with [%d].\n" status_code);
          cleanup ();
          status_code
        | WSIGNALED signo ->
          logInfo (Printf.sprintf "Child terminated with signal [%d].\n" signo);
          cleanup ();
          (128 + signo)
        | _ ->
          (* ignore stopped *)
          supervise_pid cleanup n
      end
    | _ ->
      (* some other child exited, we reap it and continue *)
      supervise_pid cleanup n
  with
  | Unix_error (ECHILD, _, _) ->
    (* no more children, maybe we missed it? *)
    logError "Lost the child process.";
    255
  | Unix_error (EINTR, _, _) ->
    (* our wait got interrupted, restart it *)
    supervise_pid cleanup n

let supervise ?cleanup:(cleanup=None) f =
  match fork () with
    | 0 -> f (); exit 0
    | n ->
      let handler signo =
        logInfo (Printf.sprintf "Forwarding signal [%d] to [%d].\n" signo n);
        safe_kill n signo
      in
      set_signal sigint (Signal_handle handler);
      set_signal sigterm (Signal_handle handler);
      let cleanup_fun =
        match cleanup with
        | Some (Kill_pid pid) -> graceful_kill pid
        | Some Kill_group -> graceful_kill (-n)
        | Some Kill_parent_group -> graceful_kill (- getpid ())
        | None -> fun _ -> ()
      in
      try
        supervise_pid cleanup_fun n
      with
      | e ->
        logError "Supervisor raised an uncaught error:";
        logValue e;
        254
