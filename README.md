[![CircleCI](https://circleci.com/gh/burgerdev/ocaml-addressmapper.svg?style=shield)](https://circleci.com/gh/burgerdev/ocaml-addressmapper) 
[![](https://images.microbadger.com/badges/image/burgerdev/ocaml-addressmapper.svg)](https://microbadger.com/images/burgerdev/ocaml-addressmapper "MicroBadger")

# OCaml-AddressMapper

Implementation of a [postfix tcp lookup table][1] that transforms the
requested address according to a confiugrable set of mapping rules. A common
use case is to transform an address to a canonical form.

Built-in mapping rules are `accept`, `reject`, `match` a regular expression
and `replace` a regular expression with a fixed string. Those can be combined
with `all` and `first`. Additionally, you can use the case transforming rules
`lower` and `upper`. The mapping rules are specified as S-expressions:

```lisp
(all
 (matches "^.*@example.com$")
 (replace "+[^@]*@" "@")
)
```

This accepts emails for domain `example.com` and removes a sub-address (the
plus part).

[1]: http://www.postfix.org/tcp_table.5.html

## Build

### Prerequisites

  * Ocaml >= 4.04.2
  * Opam

### Build on Host

```bash
make fetch_deps # installs dependencies using opam
make all
```

### Build in Development Container

There's a special [docker image][2] for building this project. Run the above
commands inside the container, or use the `docker-build.sh` script.

```bash
# build and execute tests
export CI=true
bash docker-build.sh alpine
```

[2]: https://hub.docker.com/r/burgerdev/ocaml-addressmapper-devel

## Run

```
./main.native --help
```

Command line arguments:

  - `-r <file>`
    path to the rules file on the container (default: `/rules/rules.sexp`)
  - `-b <address>`
    IP address to bind to (default: 127.0.0.1)
  - `-p <port>`
    listening port (default: 30303)
  - `-u`
    re-read the rules file for each request (default: false)

# Docker Image

Run the AddressMapper as a docker container in the background, forward the port
to `localhost:30303` and use the rules file `/tmp/rules.sexp` below.

```bash
docker run -d -p 30303:30303 -v /tmp/rules.sexp:/rules.sexp:ro burgerdev/ocaml-addressmapper
```

```lisp
(all

 (all
  lower
  (replace "+[^@]*@" "@")
 )

 (first
  (all (matches "sauron@mord.or") reject)
  (all (matches ".*@business.com") (first (matches "ceo@.*") (matches "pr@.*")))
  (matches "donations@nonprofit\.org")
 )

)
```

This file contains the following instructions (see 
[configuration.md](configuration.md) for an explanation of the addressmapper
rules):

  1. First block: address sanitizing.

     1. Convert the email address to lower case.
	 2. Strip the [sub-addresses](https://en.wikipedia.org/wiki/Email_address#Sub-addressing).
  2. Second block: user database. If any of the sub-clauses matches, we got our 
     user.

     1. If the user is Sauron, he will not get in. Nobody likes a spoilsport.
	 2. There are two acceptable users at `business.com`, the *CEO* and the 
        *Public Relations Department*.
     3. The non-profit organization has just one email address, which is reserved
        for raising funds.

Let's see some examples for how to use the container we spawned:

```
echo "get CEO@business.COM" | nc localhost 32768
# we convert everything to lower case, so the result should be 
# '200 ceo@business.com'.

echo "get donations+fundraiser2017@nonprofit.org" | nc localhost 32768
echo "get donations+fundraiser2017@nonprofit.org" | nc localhost 32768
# Both with and without a sub-address, this should result in 
# '200 donations@nonprofit.org'.

echo "get sauron@mord.or"
# Sauron is explicitly excluded, this should be '500 not-found'.

echo "put sauron@mord.or" | nc localhost 32768
# This is not valid postfix mapper syntax, therefore '400 malformed request'.
```


