#!/bin/bash

set -ex

if [[ -n "$1" ]]
then
    file_variant=".$1"
    tag_variant="-$1"
else
    file_variant=""
    tag_variant=""
fi

build_dir=.build
rm -rf $build_dir

version=`git describe --abbrev=0 --tags`

tag=burgerdev/ocaml-addressmapper-devel:$version$tag_variant

pushd .circleci/images/ocaml-addressmapper-devel
docker build -t $tag -f Dockerfile$file_variant .
popd

container=$(docker run -d -v $(pwd):/home/opam/project:ro $tag /bin/sh -c "cp -r /home/opam/project /home/opam/project2; cd /home/opam/project2; git clean -df; make all")

docker wait $container

docker cp $container:/home/opam/project2/_build $build_dir

cp $build_dir/src/main.native .circleci/images/ocaml-addressmapper/

prodtag=burgerdev/ocaml-addressmapper:$version$tag_variant

pushd .circleci/images/ocaml-addressmapper
docker build -t $prodtag -f Dockerfile$file_variant .
popd

docker rm $container

