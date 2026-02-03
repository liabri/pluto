FROM alpine:3.21.3

LABEL org.opencontainers.image.title="minecraft-server"
LABEL org.opencontainers.image.authors="liabri"

ARG JDK21_VERSION=21.0.6_p7-r0

RUN apk add --no-cache openjdk21-jre${JAVA_VERSION:+=}${JAVA_VERSION} socat
RUN addgroup -g 1000 operator && \
	adduser -D -u 1000 -G operator operator

WORKDIR /srv/minecraft
RUN chown operator:operator /srv/minecraft

COPY --chown=operator:operator entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER operator
EXPOSE 25565 
# maybe temp? expose thru caddy reverse proxy or something.

# initialise rcon socat bridge
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
