#!/bin/sh

set -e

IMAGE_NAME="minecraft-server"

podman build -t "$IMAGE_NAME" .
