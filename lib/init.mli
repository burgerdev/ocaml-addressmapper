
val supervise: (unit -> unit) -> Unix.process_status
(** [supervise f] runs the given function f in a forked process and returns
    this process' exit status. The supervising process waits on all children that
    get assigned to it, thus reaping zombies caused by double-forks (e.g.
    [Unix.establish_server]) when running as pid 1 in a container. *)

val string_of_signal: int -> string
(** [string_of_signal s] tries to convert the OCaml signal number [s] to its
    canonical string representation, e.g. SIGTERM. Only a small subset of the
    available signals is actually implemented, all others are converted using
    [string_of_int]. *)
