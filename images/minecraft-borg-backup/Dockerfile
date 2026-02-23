FROM alpine:latest AS fetcher
RUN apk add --no-cache supercronic libgcc libstdc++ curl

# create crontab for daily 5am
RUN echo "0 5 * * * /usr/bin/rcon-backup" > /crontab

RUN curl -fL https://github.com/borgbackup/borg/releases/download/1.4.3/borg-linux-glibc231-x86_64 \
	-o /usr/bin/borg && \
	chmod +x /usr/bin/borg

FROM alpine:latest as rcon-backup-builder
RUN apk add --no-cache go

WORKDIR /build
RUN go mod init rcon-backup && go get github.com/gorcon/rcon
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o rcon-backup main.go



FROM debian:bookworm-slim
LABEL org.opencontainers.image.title="minecraft-borg-backup"
LABEL org.opencontainers.image.authors="liabri"

COPY --from=fetcher /lib /lib
COPY --from=fetcher /usr/lib /usr/lib
COPY --from=fetcher /tmp /tmp

COPY --from=rcon-backup-builder /build/rcon-backup /usr/bin/rcon-backup
COPY --from=fetcher /crontab /app/crontab
COPY --from=fetcher /usr/bin/borg /usr/bin/borg
COPY --from=fetcher /usr/bin/supercronic /usr/bin/supercronic

USER 65534:65534

ENV BORG_REPO=/repo
ENV BORG_CACHE_DIR=/repo/.cache
ENV HOME=/repo
ENV BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes

#ENTRYPOINT ["/usr/bin/supercronic"]
#CMD ["/app/crontab"]
CMD ["/usr/bin/rcon-backup"]

