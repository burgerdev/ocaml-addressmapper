#!/bin/bash

set -ex

# determine final docker tag

if [[ -n "$1" ]]
then
    file_variant=".$1"
else
    file_variant=""
fi

patch=""
for extra in "$@"
do
    if [[ -n "$extra" ]]
    then
        patch="$patch-$extra"
    fi
done

version="`git describe --abbrev=0 --tags`"

oam_repo="burgerdev/"

function prepare_image {
    imagedir=".circleci/images/$1"
    image="${oam_repo}$1:$version$patch"
}

function build_image {
    docker build -t $image -f $imagedir/Dockerfile$file_variant $imagedir
}

# build devel image first, compile main.native from there

prepare_image ocaml-addressmapper-devel
build_image ocaml-addressmapper-devel

contdir="/home/opam/project"

function docker_make {
    prog="export TERM=dumb
          cp -r $contdir ${contdir}2
          cd ${contdir}2
          ls -la
          git clean -dfx
          make $@"
}

function docker_create {
    container=$(docker create "$@" $image /bin/sh -c "$prog")
    docker cp $(pwd) $container:$contdir
}

if [[ -n "$CI" ]]
then
    docker_make clean fetch_deps test doc
    docker_create
    docker start -a $container
    docker rm "$container"
fi

docker_make clean fetch_deps build

docker_create
docker start -a "$container"

prepare_image ocaml-addressmapper

build_dir=.build
rm -rf $build_dir
docker cp $container:/home/opam/project2/_build $build_dir
cp $build_dir/default/bin/main.exe $imagedir/main.native
docker rm $container

build_image ocaml-addressmapper

function assert_expected {
    actual=$(mktemp)
    expected=$(mktemp)
    docker exec $container /bin/sh -c "echo -e '$1' | nc localhost 30303" >"$actual"
    echo -ne "$2" >"$expected"
    if ! diff "$actual" "$expected"
    then
        return 1
    else
        rm -f "$actual" "$expected"
    fi
}

function cleanup {
    if [[ -z "$DEBUG" ]]
    then
        docker kill "$container" || true
        docker rm "$container" || true
    fi
}

if [[ -n "$CI" ]]
then
    trap cleanup exit
    container=$(docker create \
        $image -r /rules.sexp -b 0.0.0.0)

    docker cp "$(pwd)/test/rules.sexp" $container:/rules.sexp
    docker start $container
    sleep 2

    assert_expected "health" "200 ok\n"

    assert_expected "get abcd" "200 bbcd\n"
    assert_expected "get wxyz" "200 wxyz\n"
    assert_expected "get aazz" "500 not found\n"

    assert_expected "get ab0011856cd" "200 bbNUMBERScd\n"
    assert_expected "get ab0cd1" "200 bbNUMBERScd1\n"

    # switched off connection keep-alive because it does not work well with postfix
    # assert_expected "get abcd\nget wxyz" "200 bbcd\n200 wxyz\n"
fi
