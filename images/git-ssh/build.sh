#!/bin/sh

set -e

IMAGE_NAME="git-ssh"

podman build -t "$IMAGE_NAME" .
