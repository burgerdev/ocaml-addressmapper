open Unix
open Sys

let string_of_signal = function
  | i when i = sigint -> "SIGINT"
  | i when i = sigterm -> "SIGTERM"
  | i when i = sigkill -> "SIGKILL"
  | i when i = sigquit -> "SIGQUIT"
  | i when i = sigabrt -> "SIGABRT"
  | i when i = sigsegv -> "SIGSEGV"
  | i when i = sigfpe -> "SIGFPE"
  | i -> string_of_int i

type cleanup =
  | Kill_group
  | Kill_parent_group
  | Kill_pid of int

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
      Logs.warn (fun m -> m "Could not kill all children.");
      safe_kill whom sigkill;
      (* TODO if we were not part of the killed processes *)
      (* safe_kill 0 sigkill ??? *)
    with
    | _ ->
      (* ignore cleanup errors *)
      Logs.err (fun m -> m "Errors occured during cleanup.");
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
          Logs.info (fun m -> m "Child exited with [%d]." status_code);
          cleanup ();
          cause
        | WSIGNALED signo ->
          Logs.info (fun m -> m "Child terminated with signal [%s]." (string_of_signal signo));
          cleanup ();
          cause
        | _ ->
          (* ignore stopped *)
          supervise_pid cleanup n
      end;
    | _ ->
      (* some other child exited, we reap it and continue *)
      supervise_pid cleanup n
  with
  | Unix_error (EINTR, _, _) ->
    (* our wait got interrupted, restart it *)
    supervise_pid cleanup n

let supervise ?cleanup:(cleanup=None) f =
  match fork () with
    | 0 -> f (); exit 0
    | n ->
      Logs.info (fun m -> m "[%d]: Supervising [%d]." (getpid ()) n);
      let handler signo =
        Logs.debug (fun m -> m "[%d]: Forwarding signal [%s] to [%d]." (getpid ()) (string_of_signal signo) n);
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
      supervise_pid cleanup_fun n
