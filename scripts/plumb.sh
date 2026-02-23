#!/bin/sh
# Usage: plumb.sh <container-name>

err() { printf '\033[31m[ERROR]\033[0m[plumb.sh] %s\n' "$*"; }
inf() { printf '[INFO][plumb.sh] %s\n' "$*"; }
ok() { printf '\033[32m[ OK ]\033[0m[plumb.sh] %s\n' "$*"; }

# ensure root 
if [ "$(id -u)" -ne 0 ]; then
	log "Error: This script must be run as a root."
	exit 1
fi

# fetch variables for container from network.conf
# NAME_A
# NAME_B
# IP_A
# IP_B
# INTERFACE_A
# INTERFACE_B
PODMAN_USER="liam"

container="$1"; sot="/home/liam/network.conf"; s=0
[ -z "$container" ] && echo "Usage:: . $0 <container-name>" && return 1
[ ! -f "$sot" ] && err "$sot not found." && return 1

while IFS= read -r l; do
	case "$l" in ''|\#*) continue ;;
		\[*\]) [ "${l#\[}" = "$container]" ] && s=1 || s=0; continue ;;
	esac
	[ "$s" -eq 1 ] && export "$l"
done < "$sot"

# default values
: "${INTERFACE_A:=}"
: "${INTERFACE_B:=eth0}"

# fetch pids of rootless containers (if host is present, there is no container pid)
if [ "$NAME_A" != "host" ]; then
	PID_A=$(su - "$PODMAN_USER" -c "podman inspect -f '{{.State.Pid}}' $NAME_A" 2>/dev/null)
	if [ -z "$PID_A" ] || [ "$PID_A" -eq 0 ]; then err "Container $NAME_A not running."; exit 1; fi
fi

PID_B=$(su - "$PODMAN_USER" -c "podman inspect -f '{{.State.Pid}}' $NAME_B" 2>/dev/null)
if [ -z "$PID_B" ] || [ "$PID_B" -eq 0 ]; then err "Container $NAME_B not running."; exit 1; fi

do_veth_pair() {
	# generate temporary host-side handles to avoid collisions
	VETH_A="${NAME_B}"
	VETH_B="${NAME_B}b"

	# only plumb if the container does not have eth0
	if nsenter -t "$PID_B" -n ip link show eth0 >/dev/null 2>&1; then
		inf "Container $NAME_B already has eth0. Done."
		exit 0
	fi
	
	# remove old plumbing
	ip link del "$VETH_A" 2>/dev/null || true
	
	inf "Plumbing $NAME_A <-> $NAME_B..."
	
	#  birth the wire on the host
	ip link add "$VETH_A" type veth peer name "veth0"
	
	# inject & configure side a
	# if side a is host
	if [ "$NAME_A" = "host" ]; then
		ip link set "$VETH_A" name "$INTERFACE_A"
		ip addr add "$IP_A/31" dev "$INTERFACE_A"
		ip link set "$INTERFACE_A" up
		inf "Side A successfully configured on host as $INTERFACE_A."
	else
		ip link set "$VETH_A" netns "$PID_A"
		nsenter -t "$PID_A" -n ip link set "$VETH_A" name "$INTERFACE_A"
		nsenter -t "$PID_A" -n ip addr add "$IP_A/31" dev "$INTERFACE_A"
		nsenter -t "$PID_A" -n ip link set "$INTERFACE_A" up
		inf "Side A successfully injected into container $NAME_A as $INTERFACE_A."
	fi
	
	# inject & configure side b
	ip link set "veth0" netns "$PID_B"
	nsenter -t "$PID_B" -n ip link set dev "veth0" name "$INTERFACE_B"
	nsenter -t "$PID_B" -n ip addr add "$IP_B/31" dev "$INTERFACE_B"
	nsenter -t "$PID_B" -n ip link set "$INTERFACE_B" up
	nsenter -t "$PID_B" -n ip route add default via "$IP_A"
	inf "Side B successfully injected into $NAME_B as $INTERFACE_B."
	
	# routing
	nsenter -t "$PID_B" -n ip route add default via "$IP_A" 2>/dev/null || true
	
	# forwarding (from side a)
	nsenter -t "$PID_B" -n sysctl -w net.ipv4.ip_forward=1 >/dev/null

	if [ "$NAME_A" != "host" ]; then
		nsenter -t "$PID_A" -n sysctl -w net.ipv4.ip_forward=1 >/dev/null
	fi
	
	ok "Veth pair successfully created."
}

do_port_forward() {
	if [ "$NAME_A" = "host" ] && [ -n "$PORTS" ]; then
		inf "Poking holes for ports: $PORTS."
	
		# ensure nat structure exists
		nft add table ip nat 2>/dev/null
		nft "add chain ip nat prerouting { type nat hook prerouting priority -100 ; }" 2>/dev/null
		nft "add chain ip nat postrouting { type nat hook postrouting priority 100 ; }" 2>/dev/null
	
		# add dnat rules
		nft add rule ip nat prerouting tcp dport "{ $PORTS }" counter dnat to "$IP_B" comment "pluto-forward"
	
		# allow forwarding via filter table
		nft add table ip filter 2>/dev/null
		nft "add chain ip filter forward { type filter hook forward priority 0 ; policy accept ; }" 2>/dev/null
		nft add rule ip filter forward iifname "host-pub" accept
		nft add rule ip filter forward oifname "host-pub" accept	

		# masquerade traffic leaving the host, this ensure NAME_B knows how to reply via the host
		nft add rule ip nat postrouting oifname "$INTERFACE_A" masquerade comment "pluto-masq"
	
		# enable kernel forwarding
		sysctl -w net.ipv4.ip_forward=1 >/dev/null

		ok "Ports $PORTS successfully forwarded."
	fi
}

do_veth_pair
if [ "$NAME_A" = "host" ]; then
	do_port_forward
fi

ok "Link $NAME_A <-> $NAME_B successfully established."
