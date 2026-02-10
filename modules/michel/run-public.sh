#!/bin/sh

# this is for when static ips can be assigned to containers inside pods. this http-reverse-proxy will be taken out of pod-frangisk. for now, it must stay in there.

BASE="$HOME/modules/michel"

podman run -d --replace --name rproxy-edge \
	--network=none \
	-v "$BASE/rproxy-edge:/etc/caddy:ro" \
	localhost/caddy-reverse-proxy:latest \
	run --config /etc/caddy/Caddyfile
