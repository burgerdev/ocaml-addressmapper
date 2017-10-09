FROM phusion/baseimage:0.9.22

ENV MAPPING_RULES="/rules/rules.sexp"

ADD https://4-87226222-gh.circle-artifacts.com/0/address-mapper /address-mapper

RUN mkdir -p /etc/service/addressmapper && \
    echo '#!/bin/sh' >/etc/service/addressmapper/run && \
    echo 'exec /address-mapper -r "${MAPPING_RULES}"  -b "0.0.0.0" -p 30303 2>&1 >/dev/stdout' >>/etc/service/addressmapper/run && \
    chmod a+x /etc/service/addressmapper/run /address-mapper

EXPOSE 30303
