FROM alpine

LABEL org.label-schema.vcs-ref=2621447 \
      org.label-schema.vcs-url="https://github.com/burgerdev/ocaml-addressmapper"

ADD https://142-87226222-gh.circle-artifacts.com/0/main.alpine /main.native
RUN chmod a+x /main.native

ENTRYPOINT ["/bin/sh", "-c", "/main.native \"$@\"", "/main.native"]

EXPOSE 30303
