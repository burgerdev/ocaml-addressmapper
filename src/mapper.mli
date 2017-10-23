(* rule evaluation *)
(* =============== *)

type ('a, 'b) rule
(* a rule maps an input string to an optional output string *)

val apply: ('a, 'b) rule -> 'a -> 'b option
(* [apply r i] applies rule [r] to input [i] *)

(* first class rules *)
(* ================= *)

val bind: ('a, 'b) rule -> ('b -> 'c option) -> ('a, 'c) rule

val return: ('a -> 'b option) -> ('a, 'b) rule

(* short-hand for common use cases *)
(* =============================== *)

val accept: ('a, 'a) rule
(* a rule that always returns the input string *)

val reject: ('a, 'b) rule
(* a rule that always returns [None] *)

val lower: (string, string) rule
(* a rule that returns the input lowercased *)

val upper: (string, string) rule
(* a rule that returns the input uppercased *)

val matches: string -> (string, string) rule
(* [matches a] returns the input iff it matches regex [a] *)

val replace: string -> string -> (string, string) rule
(* [replace a b] replaces the first occurrence of regex [a] with string [b] *)

val constant: 'b -> ('a, 'b) rule
(* [constant a] always returns [a] *)

val all: ('a, 'a) rule list -> ('a, 'a) rule
(* [all r] returns what the last rule returned iff all rules returned [Some],
   otherwise it returns [None]. if [r] is empty, it returns the input. *)

val first: ('a, 'b) rule list -> ('a, 'b) rule
(* [first r] returns what the first applicable rule returned. If [r] is empty,
   it returns [None]. *)

val not: ('a, 'b) rule -> ('a, 'a) rule
(* [not r] returns the input if [r] returns [None], otherwise it returns
   [None] *)
