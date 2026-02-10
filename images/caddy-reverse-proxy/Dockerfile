FROM alpine:latest AS builder

LABEL org.opencontainers.image.title="caddy"
LABEL org.opencontainers.image.description="a caddy reverse proxy"
LABEL org.opencontainers.image.authors="liabri"

RUN apk add --no-cache go xcaddy
RUN CGO_ENABLED=0 xcaddy build \
	--with github.com/mholt/caddy-l4 \
	--output /usr/bin/caddy


FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

USER 65532
WORKDIR /home/nonroot

EXPOSE 80 443 25565

ENTRYPOINT ["/usr/bin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile"]
