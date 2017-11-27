(* Rule Evaluation *)
(* =============== *)

type rule
(* the abstract type [rule] encodes how to map an input string to an optional
   output string *)

type t = rule
(* [t] is the conventional alias for [rule] *)

val apply: rule -> string -> string option
(* [apply r i] applies rule [r] to input [i] *)

(* Constructing Rules *)
(* ================== *)

val rule_of_sexp: Sexplib.Sexp.t -> rule
(* [rule_of_sexp s] parses [s] according to the documented grammar *)

val t_of_sexp: Sexplib.Sexp.t -> t
(* [t_of_sexp] is an alias for [rule_of_sexp] *)

val accept: rule
(* a rule that always returns the input string *)

val reject: rule
(* a rule that always returns [None] *)

val lower: rule
(* a rule that returns the input lowercased *)

val upper: rule
(* a rule that returns the input uppercased *)

val matches: string -> rule
(* [matches a] returns the input iff it matches regex [a] *)

val equals: string -> rule
(* [equals a] returns the input iff it exactly equals [a] *)

val prefix_matches: string -> rule
(* [prefix_matches p] returns the input iff string [p] is a prefix of input *)

val suffix_matches: string -> rule
(* [suffix_matches s] returns the input iff string [s] is a suffix of input *)

val replace: string -> string -> rule
(* [replace a b] replaces the first occurrence of regex [a] with string [b] *)

val constant: string -> rule
(* [constant a] always returns [a] *)

val all: rule list -> rule
(* [all r] returns what the last rule returned iff all rules returned [Some],
   otherwise it returns [None]. if [r] is empty, it returns the input. *)

val first: rule list -> rule
(* [first r] returns what the first applicable rule returned. If [r] is empty,
   it returns [None]. *)

val not: rule -> rule
(* [not r] returns the input if [r] returns [None], otherwise it returns
   [None] *)

(* Utilities *)
(* ========= *)

val log_src: Logs.src
(* [log_src] is the [Logs.src] used by this module *)

val pp_rule: Format.formatter -> rule -> unit
(* [pp_rule ppf r] prints a summary of [r] to [ppf] (only the topmost rule is
   shown if [r] is an aggregated rule) *)

val pp: Format.formatter -> rule -> unit
(* [pp] is an alias for [pp_rule] *)

val dump_rule: Format.formatter -> rule -> unit
(* [dump_rule ppf r] dumps [r] in a format suitable for a rule file
   (sexp-based). *)

val dump: Format.formatter -> rule -> unit
(* [dump] is an alias for [dump_rule] *)
