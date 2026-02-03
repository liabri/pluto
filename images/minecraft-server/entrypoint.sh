#!/bin/sh
set -e 

# remove old socket if exists
rm -f /tmp/rcon.sock

# initialise bridge (mc tcp -> socket)
socat UNIX-LISTEN:/tmp/rcon.sock,fork,mode=770,group=1000 TCP4:127.0.0.1:25575 &

sleep 0.2

exec "$@"
