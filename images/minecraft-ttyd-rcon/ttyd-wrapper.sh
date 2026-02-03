#!/bin/sh
# /usr/local/bin/ttyd-wrapper

# initialise internal bridge
socat TCP4-LISTEN:25575,bind=127.0.0.1,fork UNIX-CONNECT:/tmp/rcon.sock >/dev/null 2>&1 &

# wait for log file to exist before tailing it to fill up ttyd
while [ ! -f /srv/minecraft-server/logs/latest.log ]; do 
	sleep 1 
done
clear
tail -n -5000 -f /srv/minecraft-server/logs/latest.log &
TAIL_PID=$!

# block until server is done initialising
( tail -n +1 -F /srv/minecraft-server/logs/latest.log & ) | grep -q "Done (" >/dev/null 2>&1

# run rcon-cli, and if server restarts, ttyd wont die
while true; do
	rcon-cli --host 127.0.0.1 --port 25575 --password "$RCON_PASSWORD"
	echo -e "RCON DISCONNECTED: RETRYING IN 5S..."
	sleep 5
done

# cleanup
kill $TAIL_PID
