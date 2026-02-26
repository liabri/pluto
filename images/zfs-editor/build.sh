#!/bin/sh

set -e

IMAGE_NAME="zfs-editor"

podman build -t "$IMAGE_NAME" .
