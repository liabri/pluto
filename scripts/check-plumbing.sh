#!/bin/sh

if [ $# -gt 0 ]; then
	_pid=$(podman inspect -f '{{.State.Pid}}' "$1")
	doas nsenter -t "$_pid" -n ip addr show
	exit 1;
fi

# check veth interfaces inside rproxy-edge (public) container
echo "Interfaces inside rproxy-edge"
_pid=$(podman inspect -f '{{.State.Pid}}' rproxy-edge)
doas nsenter -t "$_pid" -n ip addr show

# check veth interfaces inside vpn-edge (private) container

# check veth interface in host
echo "Interfaces inside host"
ip addr show
