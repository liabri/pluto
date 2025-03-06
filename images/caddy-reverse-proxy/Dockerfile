FROM alpine:3.21.3

LABEL org.opencontainers.image.title=Caddy
LABEL org.opencontainers.image.description="a caddy reverse proxy"
LABEL org.opencontainers.image.authors=Liam

ARG CADDY_VERSION=2.8.4-r4

RUN set -x \
	&& apk add --no-cache \
	libcap \
	caddy${CADDY_VERSION:+=}${CADDY_VERSION} \
	&& rm -rvf /var/cache/apk/* \
	&& rm -rvf /etc/caddy/Caddyfile
	

RUN apk add --no-cache \
	ca-certificates \
	libcap \
	mailcap  

EXPOSE 80
EXPOSE 443
EXPOSE 443/udp
EXPOSE 2019

ENTRYPOINT ["/usr/sbin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile"]
