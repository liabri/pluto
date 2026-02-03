#!/bin/sh

BASE="$HOME/modules/eligius"
GIT_DIR="$BASE/storage/git"

# ensure containers have permission to found git folder
podman unshare chown -R 1000:1000 "$BASE/git"

# cgit container -- this allows someone to view the repositories
podman run --replace -d --name cgit \
	--network=public
	-v "$BASE/cgit/var:/var:ro" \
	-v "$BASE/cgit/etc/cgitrc:/etc/cgitrc:ro" \
	-v "$GIT_DIR:/home/git/repos:ro" \
	localhost/cgit:latest \
	-D -f /etc/lighttpd/lighttpd.conf

# git-ssh container -- this allows someone to interact with the repository
podman run --replace -d --name git-ssh \
	--network=privat
	-v "$GIT_DIR:/home/git/repos:rw" \
	-v "$BASE/git-ssh/authorized_keys:/home/git/.ssh/authorized_keys:ro \
	localhost/git-ssh:latest
