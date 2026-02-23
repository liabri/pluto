FROM alpine:latest AS fetcher
RUN apk add --no-cache libgcc libstdc++ curl

RUN curl -fL https://github.com/borgbackup/borg/releases/download/1.4.3/borg-linux-glibc231-x86_64 \
	-o /usr/bin/borg && \
	chmod +x /usr/bin/borg

FROM alpine:latest as world-pull-builder
RUN apk add --no-cache go

WORKDIR /build
RUN go mod init world-pull && go get github.com/gorcon/rcon
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o world-pull main.go



FROM debian:bookworm-slim
LABEL org.opencontainers.image.title="minecraft-world-pull"
LABEL org.opencontainers.image.authors="liabri"

COPY --from=fetcher /lib /lib
COPY --from=fetcher /usr/lib /usr/lib
COPY --from=fetcher /tmp /tmp

COPY --from=world-pull-builder /build/world-pull /usr/bin/world-pull
COPY --from=fetcher /usr/bin/borg /usr/bin/borg

USER 65534:65534

ENV BORG_REPO=/repo
ENV BORG_CACHE_DIR=/repo/.cache
ENV HOME=/repo
ENV BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes

CMD ["/usr/bin/world-pull"]

