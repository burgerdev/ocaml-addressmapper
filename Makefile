
jbuilder=opam exec jbuilder

all: build

build:
	$(jbuilder) build @install

test: build
	$(jbuilder) runtest
	/bin/sh ./test/test-binary.sh

doc:
	$(jbuilder) build @doc

clean:
	$(jbuilder) clean

fetch_deps:
	opam install -y ocamlfind odoc ounit sexplib mparser cmdliner logs fmt jbuilder

.PHONY: build all test doc clean fetch_deps
