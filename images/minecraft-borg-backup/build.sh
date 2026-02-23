#!/bin/sh

set -e

IMAGE_NAME="minecraft-borg-backup"

podman build -t "$IMAGE_NAME" .
