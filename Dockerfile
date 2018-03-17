FROM burgerdev/ocaml-build:4.06-0 as build

ADD --chown=opam:nogroup lib ./lib
ADD --chown=opam:nogroup bin ./bin
ADD --chown=opam:nogroup mapper.opam ./mapper.opam

RUN echo "(-cclib -static)" >bin/link_flags && \
    eval `opam config env` && jbuilder build

FROM scratch

COPY --from=build /home/opam/_build/default/bin/main.exe /mapper

EXPOSE 30303

ENTRYPOINT ["/mapper", "-i"]
CMD ["-b", "0.0.0.0", "-v"]
