#!/bin/sh

set -e

IMAGE_NAME="lighttpd"

podman build -t "$IMAGE_NAME" .
