#!/bin/sh

BASE="$HOME/modules/frangisk"

# lbmt-darkroom
podman run --replace -d --name lbmt-darkroom \
	--network=none \
	-v "$BASE/darkroom/lighttpd.conf:/var/lighttpd.conf:ro" \
	localhost/lbmt-darkroom:latest \
	-D -f /etc/lighttpd/lighttpd.conf

