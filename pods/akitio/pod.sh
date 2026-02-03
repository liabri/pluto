#!/bin/sh

BLOCK=akitio
BASE=/home/liam/pods/akitio
RCON_PASSWORD="testingbaby"

# ensure containers have permission to mounted files
podman unshare chown -R 1000:1000 "$BASE/minecraft-server/working-tree"

# clean /tmp/rcon.sock
podman volume rm -f rcon_ipc 2>/dev/null || true
podman volume create \
	--driver local \
	--opt type=tmpfs \
	--opt device=tmpfs \
	--opt o="size=1m,mode=770" \
	rcon_ipc

# run minecraft-server
# make sure working-tree for server is latest ver
#sh $BASE/minecraft-server/check-working-tree.sh # commented until i test rcon, then uncomment.

# eventually -p 25565:25565 wont be required, as we do not want to open it to the host, but rather only through wireguard vpn
podman run --replace -d -it --name minecraft-server \
	-p 25565:25565 \
	-v $BASE/minecraft-server/working-tree:/srv/minecraft:rw \
	-v rcon_ipc:/tmp:rw \
	-e RCON_PASSWORD="$RCON_PASSWORD" \
        --network=public \
	localhost/minecraft-server:latest \
	java -Xmx5G -jar -Dfabric.addMods=mods /srv/minecraft/fabric-server-mc.1.20.1-loader.0.16.9-launcher.1.0.1.jar

# run web terminal (ttyd using rcon-cli for ipc via unix sockets) 127.0.0.1 -p enforces that it is truly only accessible locally (i.e. via a vpn) -p 127.0.0.1:7681:7681
podman run --replace -d -it --name minecraft-ttyd-rcon \
	-p 0.0.0.0:7681:7681 \
	-v rcon_ipc:/tmp:rw \
	-v "$BASE/minecraft-server/working-tree/logs:/srv/minecraft-server/logs:ro" \
	--network=privat \
	-e RCON_PASSWORD="$RCON_PASSWORD" \
	localhost/minecraft-ttyd-rcon:latest \
#	ttyd -p 7681 --writable /bin/sh
