# build binary
FROM alpine:latest AS builder

RUN apk add --no-cache go
RUN CGO_ENABLED=0 go install github.com/sorenisanerd/gotty@latest

WORKDIR /app
RUN go mod init ttyd-wrapper && \
	go get github.com/gorcon/rcon
COPY wrapper.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o wrapper wrapper.go

FROM scratch

COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /root/go/bin/gotty /usr/local/bin/gotty
COPY --from=builder /app/wrapper /usr/local/bin/wrapper

USER 65534
ENTRYPOINT ["/usr/local/bin/gotty", "-p", "8080", "--path", "/rcon", "-w", "/usr/local/bin/wrapper"] 
