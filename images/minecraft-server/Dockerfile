FROM alpine:latest AS builder

RUN apk add --no-cache \
	openjdk21-jre \
	gcompat \
	libstdc++

FROM scratch
LABEL org.opencontainers.image.title="minecraft-server"
LABEL org.opencontainers.image.authors="liabri"

COPY --from=builder /lib /lib
COPY --from=builder /usr/lib /usr/lib
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

WORKDIR /srv/minecraft
USER 65534:65534

ENV PATH="/usr/lib/jvm/java-21-openjdk/bin:${PATH}"
ENV JAVA_HOME="/usr/lib/jvm/openjdk-21"
