
all: build test

build:
	jbuilder build

test:
	jbuilder runtest

install:
	jbuilder build @install

doc:
	jbuilder build @doc

clean:
	rm -rf .build
	rm -f *.native
	jbuilder clean

fetch_deps:
	opam install -y ocamlfind ounit sexplib mparser cmdliner logs fmt jbuilder

.PHONY: build all test install doc clean fetch_deps
