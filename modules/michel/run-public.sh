#!/bin/sh

BASE="$HOME/modules/michel"

podman run -d --replace --name rproxy-edge \
	--network=none \
	-v "$BASE/rproxy-edge:/etc/caddy:ro" \
	--cap-add=NET_BIND_SERVICE \
	localhost/caddy-reverse-proxy:latest \
	run --config /etc/caddy/Caddyfile

doas sh "$HOME/scripts/plumb.sh" rproxy-edge
