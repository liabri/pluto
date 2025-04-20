FROM alpine:3.21.3

LABEL org.opencontainers.image.title="lighttpd"
LABEL org.opencontainers.image.description="provides a simple lighttpd server (supporting html & cgi) at /var/www/html on a port defined in the container"
LABEL org.opencontainers.image.authors="liabri"

ARG LIGHTTPD_VERSION=1.4.79-r0

RUN set -x \
    && apk add --no-cache \
    lighttpd${LIGHTTPD_VERSION:+=}${LIGHTTPD_VERSION} \
    lighttpd-mod_auth${LIGHTTPD_VERSION:+=}${LIGHTTPD_VERSION} \
    && rm -rvf /var/cache/apk/* \
    && rm -rvf /etc/lighttpd/* /etc/logrotate.d/lighttpd /var/log/lighttpd /var/www/localhost \
    && mkdir -vp /var/www/html

COPY lighttpd/ /etc/lighttpd/

ENTRYPOINT ["/usr/sbin/lighttpd"]
CMD ["-D", "-f", "/etc/lighttpd/lighttpd.conf"]
