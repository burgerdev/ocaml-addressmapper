
all: build test

build:
	jbuilder build

test:
	jbuilder runtest

install:
	jbuilder build @install

clean:
	rm -rf .build
	rm -f *.native
	jbuilder clean

fetch_deps:
	opam install -y ocamlfind ounit sexplib cmdliner logs fmt jbuilder

.PHONY: build all test install clean fetch_deps
