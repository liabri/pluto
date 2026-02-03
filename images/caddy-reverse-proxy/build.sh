#!/bin/sh

set -e

IMAGE_NAME="caddy-reverse-proxy"

podman build -t "$IMAGE_NAME" .
