#!/bin/sh

BASE="$HOME/modules/isidore"
ZFS="$HOME/storage"

err() { c="$1"; shift; printf '\033[31m[ERROR]\033[0m[run.sh][%s] %s\n' "$c" "$*"; }
inf() { c="$1"; shift; printf '[INFO][run.sh][%s] %s\n' "$c" "$*"; }
ok() { c="$1"; shift; printf '\033[32m[ OK ]\033[0m[run.sh][%s] %s\n' "$c" "$*"; }

# a web editor for files in zfs storage
podman run --replace -d -it --name zfs-editor \
	--network=none \
	-v "$ZFS/docs:/docs":rw,U \
	-v "$ZFS/docs/output:/public/output":rw,U \
	-e SITE_ROOT=/editor \
	localhost/zfs-editor:latest \
	>/dev/null
ok "zfs-editor" "Container is running."
doas sh "$HOME/scripts/plumb.sh" zfs-editor

# a file watcher which renders/builds any files that change
podman run --replace -d -it --name zfs-builder \
	--network=none \
	-v "$ZFS/docs:/data":rw,U \
	localhost/zfs-builder:latest \
	>/dev/null
ok "zfs-builder" "Container is running."
