FROM ocaml/opam2:alpine-3.8-ocaml-4.07 AS build

RUN sudo apk --no-cache add m4 ncurses

ADD --chown=opam:nogroup . /src

WORKDIR /src

RUN make fetch_deps build

FROM alpine

COPY --from=build /src/_build/default/bin/main.exe  /mapper

EXPOSE 30303

ENTRYPOINT ["/mapper", "-i", "-b", "0.0.0.0"]
