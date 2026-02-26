FROM alpine:latest as builder
RUN apk add --no-cache go npm
WORKDIR /build

RUN npm install codemirror @codemirror/lang-markdown @codemirror/theme-one-dark esbuild
COPY ./src /build/src
RUN npx esbuild /build/src/editor.js --bundle --minify --outfile=bundle.js

RUN go mod init orchestrator
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o orchestrator main.go



FROM localhost/sws
LABEL org.opencontainers.image.title="zfs-editor"
LABEL org.opencontainers.image.authors="liabri"

WORKDIR /public
USER 65533:65533

COPY --from=builder /build/bundle.js ./js/bundle.js
COPY --from=builder /build/orchestrator /usr/bin/orchestrator
COPY ./static/index.html .
ENTRYPOINT [""]
CMD ["/usr/bin/orchestrator"]

