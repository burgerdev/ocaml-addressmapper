
type cleanup =
  | Kill_group
  | Kill_parent_group
  | Kill_pid of int

val supervise:
  ?cleanup:cleanup option -> (unit -> unit) -> Unix.process_status
(* [supervise c f] runs the given function f in a forked process and returns
   this process' return value. After the main child exited, leftover processes
   can be cleaned up by killing the main child's group, the supervisor's group
   or a specific PID (you might want to use '-1' if running in a container).
*)
