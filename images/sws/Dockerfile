FROM rust:1.90-alpine AS fetcher

RUN apk add --no-cache musl-dev git
WORKDIR /sws
RUN git clone https://github.com/static-web-server/static-web-server.git .
RUN cargo build --release --target x86_64-unknown-linux-musl

FROM scratch
LABEL org.opencontainers.image.title="sws"
LABEL org.opencontainers.image.description="sws from scratch"
LABEL org.opencontainers.image.authors="liabri"

COPY --from=fetcher /sws/target/x86_64-unknown-linux-musl/release/static-web-server /sws
COPY --from=fetcher /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs

ENTRYPOINT ["/sws"]
