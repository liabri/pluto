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
	--opt type=tmpfs \
	--opt device=tmpfs \
	--opt o="size=1m,mode=770" \
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

# run minecraft-server
podman run --replace -d -it --name mc-server \
	--network=none \
	--user 65532:65532 \
	--memory 4g \
	-u 65534:65534 \
	-v mc-working-tree:/srv/minecraft:rw \
	-e RCON_PASSWORD="$RCON_PASSWORD" \
	localhost/minecraft-server:latest \
	java -Xmx5G -jar -Dfabric.addMods=mods /srv/minecraft/fabric-server-mc.1.20.1-loader.0.16.9-launcher.1.0.1.jar \
	>/dev/null
ok "mc-server" "Container is running."

doas sh "$HOME/scripts/plumb.sh" mc-server

# sidecar container which exposes rcon-ip to the mc-server container 
#podman run --replace -d -it --name mc-rcon-side \
#	--network=none \
#	--user 65532:65532 \
	
#./plumb.sh mc-rcon-side

# run web terminal (ttyd using rcon-cli, ipc via unix sockets) might need to do some weird --mount stuff instead of -v to mount only mc-working-tree/logs
#podman run --replace -d -it --name mc-ttyd-rcon \
#	--network=none \
#	-v rcon-ipc:/tmp:rw \
#	--mount type=volume,source=mc-working-tree,target=/srv/minecraft-server/logs,volume-subpath=logs,ro=true \
#	-e RCON_PASSWORD="$RCON_PASSWORD" \
#	localhost/minecraft-ttyd-rcon:latest
