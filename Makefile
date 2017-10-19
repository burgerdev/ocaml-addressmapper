FLAGS=-use-ocamlfind
SOURCES=src/main.ml src/mapper.ml src/mapper.mli src/init.ml src/init.mli
TEST_SOURCES=test/test_mapper.ml

build: _build/src/main.native _build/src/supervise.native

all: build test

test: _build/test/test_mapper.native
	$<

clean:
	ocamlbuild -clean

_build/src/%.native: src/%.ml $(SOURCES)
	ocamlbuild $(FLAGS) src/$*.native

_build/test/%.native: test/%.ml $(SOURCES) $(TEST_SOURCES)
	ocamlbuild $(FLAGS) -I src test/$*.native

fetch_deps:
	opam install -y ocamlfind ounit sexplib cmdliner

.PHONY: build all test clean fetch_deps
