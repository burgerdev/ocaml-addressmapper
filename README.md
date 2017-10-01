[![](https://images.microbadger.com/badges/image/burgerdev/ocaml-addressmapper:0.2.svg)](https://microbadger.com/images/burgerdev/ocaml-addressmapper:0.2 "MicroBadger")

# OCaml-AddressMapper

Implementation of a postfix address mapping server.

Built-in mapping rules are `accept`, `reject`, `match` a regular expression
and `replace` a regular expression with a fixed string. Those can be combined
with `all` and `first`.

The mapping rules can be supplied via S-expression:

```lisp
(all
 (matches ".*@example.com")
 (replace "#[^@]*" "")
)
```

This accepts emails for domain `example.com` and removes a # mailbox suffix.

# Build

```bash
oasis setup
make
```

# Run

```
./main.native --help
```
