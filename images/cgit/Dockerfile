FROM localhost/lighttpd:latest

LABEL org.opencontainers.image.title="cgit"
LABEL org.opencontainers.image.description="provides a cgit instance to run behind a reverse proxy"
LABEL org.opencontainers.image.authors="liabri"

RUN set -ex; \
	apk add --no-cache \
	cgit \
	py3-markdown

COPY cgit.conf /etc/lighttpd/conf.d/cgit.conf
