#!/bin/sh

BASE="$HOME/modules/akitio"
WORLD_DIR="$HOME/storage/loghob/minecraft/akitio/world"
RCON_PASSWORD="testingbaby"

err() { c="$1"; shift; printf '\033[31m[ERROR]\033[0m[run.sh][%s] %s\n' "$c" "$*"; }
inf() { c="$1"; shift; printf '[INFO][run.sh][%s] %s\n' "$c" "$*"; }
ok() { c="$1"; shift; printf '\033[32m[ OK ]\033[0m[run.sh][%s] %s\n' "$c" "$*"; }

# clean /tmp/rcon.sock
podman volume rm -f mc-rcon-ipc 2>/dev/null || true >/dev/null
podman volume create \
	--driver local \
	--opt device=tmpfs \
	--opt type=tmpfs \
	--opt o="size=1m,mode=770,uid=65534,gid=65534" \
	mc-rcon-ipc \
	>/dev/null
ok "mc-rcon-ipc" "Volume is available."

# if mc-working-tree named-volume is not created, create it.
if ! podman volume exists mc-working-tree; then 
	podman volume create --driver local mc-working-tree >/dev/null
fi

if podman volume exists mc-working-tree; then
	ok "mc-working-tree" "Volume is available."
fi

# check integrity of mc-working-tree as per the origin git
WORKING_TREE_PATH=$(podman volume inspect mc-working-tree -f '{{.Mountpoint }}')
podman unshare /bin/sh $HOME/modules/akitio/check-working-tree.sh "mc-working-tree" "$WORKING_TREE_PATH"
podman unshare chown -R 65534:65534 "$WORKING_TREE_PATH"
podman unshare find "$WORKING_TREE_PATH" -type d -exec chmod 2755 {} +
podman unshare find "$WORKING_TREE_PATH" -type f -exec chmod 664 {} +

# sidecar container which loads latest ver of world into volume mc-working-tree from WORLD_DIR (which is a borg repo)
podman run --replace -d -it --name mc-world-pull \
	--network=none \
	-u 65534:65534 \
	-v mc-working-tree:/srv/minecraft:rw \
	-v "$WORLD_DIR:/repo":rw,U \
	localhost/minecraft-world-pull:latest \
	>/dev/null
ok "mc-world-pull" "Container is running"

# run minecraft-server
podman run --replace -d -it --name mc-server \
	--network=none \
	--memory 4g \
	-u 65534:65534 \
	-v mc-working-tree:/srv/minecraft:rw \
	-v mc-rcon-ip:/bridge:rw,U,z \
	-e RCON_PASSWORD="$RCON_PASSWORD" \
	localhost/minecraft-server:latest \
	java -Xmx5G -jar -Dfabric.addMods=mods /srv/minecraft/fabric-server-mc.1.20.1-loader.0.16.9-launcher.1.0.1.jar \
	>/dev/null
ok "mc-server" "Container is running."

doas sh "$HOME/scripts/plumb.sh" mc-server

# run web terminal (ttyd using rcon-cli, ipc via unix sockets) might need to do some weird --mount stuff instead of -v to mount only mc-working-tree/logs
podman run --replace -d -it --name mc-ttyd-rcon \
	--network=none \
	--volumes-from mc-server \
	--mount type=volume,source=mc-working-tree,target=/srv/minecraft-server/logs,ro=true,subpath=logs \
	-e RCON_PASSWORD="$RCON_PASSWORD" \
	localhost/minecraft-ttyd-rcon:latest \
	>/dev/null
ok "mc-ttyd-rcon" "Container is running."
doas sh "$HOME/scripts/plumb.sh" mc-ttyd-rcon

# run borg backup everyday at 5am via superchronic inside container
#podman run --replace -d -it --name mc-backup \
#	--network=none \
#	-v "$WORLD_DIR:/repo":rw,U \
#	--volumes-from mc-server \
#	--mount type=volume,source=mc-working-tree,target=/data,ro=true,subpath=world \
#	-e RCON_PASSWORD="$RCON_PASSWORD" \
#	localhost/minecraft-borg-backup:latest \
#	>/dev/null
#ok "mc-backup" "Container is running."
