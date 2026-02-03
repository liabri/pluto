#!/bin/sh

set -e

IMAGE_NAME="minecraft-ttyd-rcon"

podman build -t "$IMAGE_NAME" .
