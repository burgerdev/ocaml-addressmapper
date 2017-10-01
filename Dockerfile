FROM phusion/baseimage:0.9.22

ENV MAPPING_RULES="/rules/rules.sexp"

COPY _build/src/main.native /server

COPY run /etc/service/addressmapper/run

EXPOSE 30303
