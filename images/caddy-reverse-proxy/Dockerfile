FROM alpine:3.21.3

LABEL org.opencontainers.image.title="caddy"
LABEL org.opencontainers.image.description="a caddy reverse proxy"
LABEL org.opencontainers.image.authors="liabri"

ARG CADDY_VERSION=2.8.4-r7

RUN set -x
RUN apk add --no-cache \
	libcap \
	ca-certificates \
	caddy${CADDY_VERSION:+=}${CADDY_VERSION} \
	&& rm -rvf /var/cache/apk/* \
	&& rm -rvf /etc/caddy/Caddyfile

EXPOSE 80 443

ENTRYPOINT ["/usr/sbin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile"]
