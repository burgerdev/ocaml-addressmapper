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

oam_repo="${OAM_REPO:-burgerdev/}"
oam_project="${OAM_PROJECT:-ocaml-addressmapper}"
oam_project_devel="${OAM_PROJECT_DEVEL:-ocaml-addressmapper-devel}"

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

name="xxx-tmp-devel-container-$$"

contdir="/home/opam/project"
volume="$(pwd):$contdir:ro"

function docker_make {
    prog="cp -r $contdir ${contdir}2
          cd ${contdir}2
          git clean -dfx
          make $@"
}

if [[ -n "$OAM_TEST" ]]
then
    docker_make clean test
    docker run --name "$name" -v "$volume" $image /bin/sh -c "$prog"
    docker rm "$name"
fi

docker_make clean build

container=$(docker run -d --name "$name" -v $volume $image /bin/sh -c "$prog")
docker wait $container

prepare_image ocaml-addressmapper

build_dir=.build
rm -rf $build_dir
docker cp $container:/home/opam/project2/_build $build_dir
cp $build_dir/src/main.native $imagedir/
docker rm $container

build_image ocaml-addressmapper
