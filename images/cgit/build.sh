#!/bin/sh

set -e

IMAGE_NAME="cgit"

podman build -t "$IMAGE_NAME" .
