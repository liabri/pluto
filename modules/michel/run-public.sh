#!/bin/sh

# this is for when static ips can be assigned to containers inside pods. this http-reverse-proxy will be taken out of pod-frangisk. for now, it must stay in there.

BASE="$HOME/modules/michel"

podman run -d --replace --name http-reverse-proxy \
	--network public \
	-p 80:80 \
	-p 443:443 \
	-v "$BASE/http-reverse-proxy:/etc/caddy:ro" \
	--ip 10.89.0.10 \
	localhost/caddy-reverse-proxy:latest \
	run --config /etc/caddy/Caddyfile
