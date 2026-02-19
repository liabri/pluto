
FROM alpine:latest AS fetcher

RUN apk add --no-cache \
	openjdk21-jre \
	gcompat \
	libstdc++ 

FROM alpine:latest as init-builder

RUN apk add --no-cache go
WORKDIR /build
RUN cat <<EOF > main.go
package main
import("os"; "os/exec")
func main() {
	go OpenBridge()
	
	// this is shell's "exec '$@'"
	cmd := exec.Command(os.Args[1], os.Args[2:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Run()
}
EOF
COPY bridge.go .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -tags netgo -ldflags="-s -w -extldflags '-static'" -o init main.go bridge.go

FROM scratch
LABEL org.opencontainers.image.title="minecraft-server"
LABEL org.opencontainers.image.authors="liabri"

COPY --from=init-builder  /build/init /init
COPY --from=fetcher /lib /lib
COPY --from=fetcher /usr/lib /usr/lib
COPY --from=fetcher /etc/passwd /etc/passwd
COPY --from=fetcher /etc/group /etc/group

WORKDIR /srv/minecraft
USER 65534:65534

ENV PATH="/usr/lib/jvm/java-21-openjdk/bin:${PATH}"
ENV JAVA_HOME="/usr/lib/jvm/openjdk-21"

ENTRYPOINT ["/init"]
