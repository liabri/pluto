#!/bin/sh

set -e

IMAGE_NAME="sws"

podman build -t "$IMAGE_NAME" .
