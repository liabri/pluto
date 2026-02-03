apk add openssh
ssh-keygen -A
./usr/sbin/sshd

cd /srv/minecraft
echo "CURRENT DIRECTORY: " $PWD
ls -al
/bin/sh -c /srv/minecraft/start.sh

echo newline

stat /srv/minecraft
