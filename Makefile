FLAGS=-use-ocamlfind
SOURCES=src/main.ml src/mapper.ml src/mapper.mli src/init.ml src/init.mli src/server.ml src/server.mli
TEST_SOURCES=test/test_mapper.ml test/test_parser.ml test/test_server.ml

all: build test

build: _build/src/main.native _build/src/supervise.native

test: test_init test_mapper test_parser test_server

test_init: _build/test/test_init.native
	$<

test_mapper: _build/test/test_mapper.native
	$<

test_parser: _build/test/test_parser.native
	$<

test_server: _build/test/test_server.native
	$<

clean:
	rm -rf .build
	rm -f *.native
	ocamlbuild -clean

_build/src/%.native: src/%.ml $(SOURCES)
	ocamlbuild $(FLAGS) src/$*.native

_build/test/%.native: test/%.ml $(SOURCES) $(TEST_SOURCES)
	ocamlbuild $(FLAGS) -I src test/$*.native

fetch_deps:
	opam install -y ocamlfind ounit sexplib cmdliner logs fmt

.PHONY: build all test test_init test_mapper test_parser clean fetch_deps
