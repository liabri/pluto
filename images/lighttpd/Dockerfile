FROM alpine:3.21.3

LABEL org.opencontainers.image.title="lighttpd"
LABEL org.opencontainers.image.description="provides a simple lighttpd server (supporting html & cgi) at /var/www/html on a port defined in the container"
LABEL org.opencontainers.image.authors="liabri"

RUN set -x \
    && apk add --no-cache \
    lighttpd \
    lighttpd-mod_auth \
    && rm -rvf /var/cache/apk/* \
    && rm -rvf /etc/lighttpd/* /etc/logrotate.d/lighttpd /var/log/lighttpd /var/www/localhost \
    && mkdir -vp /var/www/html

COPY lighttpd/ /etc/lighttpd/

ENTRYPOINT ["/usr/sbin/lighttpd"]
CMD ["-D", "-f", "/etc/lighttpd/lighttpd.conf"]
