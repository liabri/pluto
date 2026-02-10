#!/bin/sh

# check veth interface inside container
echo "Interfaces inside container"
_pid=$(podman inspect -f '{{.State.Pid}}' rproxy-edge)
doas nsenter -t "$_pid" -n ip addr show

# check veth interface in host
echo "Interfaces inside host"
doas ip addr show
