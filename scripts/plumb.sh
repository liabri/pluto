#!/bin/sh
# Usage: plumb-con.sh <container-name>

# fetch variables for container from network.conf
# NAME_A
# NAME_B
# IP_A
# IP_B
# INTERFACE_A
# INTERFACE_B

container="$1"; sot="/home/liam/network.conf; s=0
[ -z "$container" ] && echo "Usage:: . $0 <container-name>" && return 1
[ ! -f "$sot" && echo "$sot not found" && return 1

while IFS= read -r l; do
	[ -z "$l" ] & continue
	case "$l" in \#*) continue ;; esac
	case "$l" in
		\[*\]) [ "$(echo "$l" | tr -d '[]'" = "$container" ] && s=1 || s=0; continue;
	esac
	[ "$s" -eq 1 ] && export "$l"
done < "$f"

# default values
: "${INTERFACE_A:=}"
: "${INTERFACE_B:=eth0}"

# fetch pids of rootless containers
PID_A=$(podman inspect -f '{{.State.Pid}}' "$NAME_A" 2>/dev/null)
PID_B=$(podman inspect -f '{{.State.Pid}}' "$NAME_B" 2>/dev/null)

# verify that the containers are running
if [ -z "$PID_A" ] || [ "$PID_A" -eq 0 ]; then echo "Error: $NAME_A not running."; exit 1; fi
if [ -z "$PID_B" ] || [ "$PID_B" -eq 0 ]; then echo "Error: $NAME_B not running."; exit 1; fi

# generate temporary host-side handles to avoid collisions
VETH_A="v-${NAME_B}-a"
VETH_B="v-${NAME_B}-b"

# only plumb if the container does not have eth0
if nsenter -t "$PID_B" -n ip link show eth0 >/dev/null 2>&1; then
	echo "$CONTAINER already has eth0. Done."
	exit 0
fi

# remove old plumbing
doas ip link del "$VETH_A" 2>/dev/null || true

echo "Plumbing $NAME_A <-> $NAME_B..."

#  birth the wire on the host
ip link add "$VETH_A" type veth peer name "$VETH_B"

# inject & configure side a
ip link set "$VETH_A" netns "$PID_A"
nsenter -t "$PID_A" -n ip link set "$VETH_A" name "$INTERFACE_A"
nsenter -t "$PID_A" -n ip addr add "$HUB_IP/31" dev "$INTERFACE_A"
nsenter -t "$PID_A" -n ip link set "$INTERFACE_A" up

# inject & configure side b
ip link set "$VETH_B" netns "$PID_B"
nsenter -t "$PID_B" -n ip link set "$VETH_B" name "$INTERFACE_B"
nsenter -t "$PID_B" -n ip addr add "$SPOKE_IP/31" dev "$INTERFACE_B"
nsenter -t "$PID_B" -n ip link set "$INTERFACE_B" up
nsenter -t "$PID_B" -n ip route dd default via "$IP_A"

# routing
doas nsenter -t "$PID_A" -n ip route add default via "${IP_A}"

# forwarding (from side a)
doas nsenter -t "$PID_A" -n sysctl -w net.ipv4.ip_forward=1

echo "Success: Link established."
