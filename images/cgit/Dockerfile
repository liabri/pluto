FROM localhost/lighttpd:latest

ARG CGIT_VERSION=1.2.3-r5

RUN set -ex; \
	apk add --no-cache \
	cgit${CGIT_VERSION:+=}${CGIT_VERSION} \
	py3-markdown

COPY resources/etc/lighttpd /etc/lighttpd/
