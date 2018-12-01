
dune=opam exec dune

all: build

build:
	$(dune) build @install

test: build
	$(dune) runtest
	/bin/sh ./test/test-binary.sh

doc:
	$(dune) build @doc

clean:
	$(dune) clean

fetch_deps:
	opam install -y odoc ounit sexplib mparser cmdliner logs fmt dune lwt

.PHONY: build all test doc clean fetch_deps
