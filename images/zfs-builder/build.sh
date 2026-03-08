#!/bin/sh

set -e

IMAGE_NAME="zfs-builder"

podman build -t "$IMAGE_NAME" .
