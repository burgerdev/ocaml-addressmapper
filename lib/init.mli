
val supervise: (unit -> unit) -> Unix.process_status
(** [supervise f] runs the given function f in a forked process and returns
    this process' exit status. The supervising process waits on all children that
    get assigned to it, thus reaping zombies caused by double-forks (e.g.
    [Unix.establish_server]) when running as pid 1 in a container. *)
