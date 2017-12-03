open Unix
open Sys

let pid_tag =
  Logs.Tag.def "pid" ~doc:"process id" (fun m -> Format.fprintf m "%d")

let get_pid_tag _ = Logs.Tag.(empty |> add pid_tag (getpid ()))

(* Why is this not part of Unix? *)
let string_of_signal = function
  | i when i = sigint -> "SIGINT"
  | i when i = sigterm -> "SIGTERM"
  | i when i = sigkill -> "SIGKILL"
  | i when i = sigquit -> "SIGQUIT"
  | i when i = sigabrt -> "SIGABRT"
  | i when i = sigsegv -> "SIGSEGV"
  | i when i = sigfpe -> "SIGFPE"
  | i -> string_of_int i

(* wait for any child to terminate, exit if process 'n' *)
let rec supervise_pid n =
  try
    match wait () with
    | (m, cause) when m = n ->
      begin
        match cause with
        | WEXITED status_code ->
          Logs.info (fun m -> m "Child exited with [%d]." status_code ~tags:(get_pid_tag ()));
          cause
        | WSIGNALED signo ->
          let s = string_of_signal signo in
          Logs.info (fun m -> m "Child killed by signal [%s]." s ~tags:(get_pid_tag ()));
          cause
        | _ ->
          (* ignore stopped *)
          supervise_pid n
      end
    | _ ->
      (* some other child exited, we reap it and continue *)
      supervise_pid n
  with
  | Unix_error (EINTR, _, _) ->
    (* our wait got interrupted, restart it *)
    supervise_pid n

let deliver_signal to_whom signo =
  let s = string_of_signal signo in
  Logs.debug (fun m -> m "Forwarding signal [%s] to [%d]." s to_whom ~tags:(get_pid_tag ());
  try kill to_whom signo with
  | Unix_error (ESRCH, _, _) ->
    Logs.warn (fun m -> m "Could not deliver signal [%s] to lost child [%d]." s to_whom ~tags:(get_pid_tag ())))

let supervise f =
  match fork () with
  | 0 ->
    (* this is the child to supervise *)
    f ();
    (* if we get to this point, the child finished it's job and we return the
       traditional 0 to indicate this to the caller. *)
    exit 0
  | n ->
    Logs.info (fun m -> m "Supervising [%d]." n ~tags:(get_pid_tag ()));
    let handler = deliver_signal n in
    set_signal sigint (Signal_handle handler);
    set_signal sigterm (Signal_handle handler);
    set_signal sigquit (Signal_handle handler);
    supervise_pid n
