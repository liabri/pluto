#!/bin/sh

set -e

IMAGE_NAME="minecraft-world-pull"

podman build -t "$IMAGE_NAME" .
