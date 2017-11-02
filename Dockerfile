FROM alpine

LABEL org.label-schema.vcs-ref=e854a4a \
      org.label-schema.vcs-url="https://github.com/burgerdev/ocaml-addressmapper"

ADD https://189-87226222-gh.circle-artifacts.com/0/main.alpine /main.native
RUN chmod a+x /main.native

ENTRYPOINT ["/main.native"]

EXPOSE 30303
