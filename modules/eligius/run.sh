#!/bin/sh

GIT_DIR="$HOME/storage/git"

# git-ssh container -- this allows someone to interact with the repository
#podman run --replace -d --name git-ssh \
#	--network=privat
#	-v "$GIT_DIR:/home/git/repos:rw" \
#	-v "$BASE/git-ssh/authorized_keys:/home/git/.ssh/authorized_keys:ro \
#	localhost/git-ssh:latest

set -eux

# cgit
# doas podman unshare chown -R 4001:4000 "$GIT_DIR"
podman run --replace -d --name git-web \
	--network=none \
	-u 4001:4000 \
	-v "$GIT_DIR":/srv/git:ro \
	localhost/cgit:latest

doas sh "$HOME/scripts/plumb.sh" git-web
