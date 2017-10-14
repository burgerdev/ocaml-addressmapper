FROM ubuntu:16.04

ADD https://64-87226222-gh.circle-artifacts.com/0/main.ubuntu /main.native

ENTRYPOINT ["/bin/sh", "-c", "/main.native \"$@\"", "/main.native"]

EXPOSE 30303
