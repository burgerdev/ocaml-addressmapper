
jbuilder=opam exec jbuilder

all: build

build:
	$(jbuilder) build @install

test: build
	$(jbuilder) runtest
	/bin/sh ./test/test-binary.sh

doc:
	$(jbuilder) build @doc

benchmark:
	$(jbuilder) build benchmark/benchmark.exe
	./_build/default/benchmark/benchmark.exe -q 1 cycles samples time -clear-columns -display tall

clean:
	$(jbuilder) clean

fetch_deps:
	opam install -y ocamlfind odoc ounit sexplib mparser cmdliner logs fmt jbuilder

.PHONY: build all test doc benchmark clean fetch_deps
