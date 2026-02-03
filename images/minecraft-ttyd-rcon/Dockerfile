# build binary
FROM alpine:latest AS builder

# get mcrcon
RUN apk add --no-cache ttyd rcon-cli socat

RUN addgroup -g 1000 operator && \
	adduser -D -u 1000 -G operator operator

COPY ttyd-wrapper.sh /usr/local/bin/ttyd-wrapper
RUN chmod +x /usr/local/bin/ttyd-wrapper

USER operator

# ttyd port
EXPOSE 7681

# start ttyd
# -i eth0 ensures it listens on the container's network interface
# /usr/local/bin/ttyd-wrapper: the only command the user can execute
ENTRYPOINT ["ttyd", "-p", "7681", "-t", "scrollback=100000", "--writable", "/usr/local/bin/ttyd-wrapper"]
