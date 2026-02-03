#!/bin/sh

# create public network
podman network rm public
podman network create \
	--subnet 10.89.0.0/24 \
	public

# create private network
podman network rm private
podman network create \
	privat
