# pluto
my personal homelab completely based on alpine and podman. all images are created by me. **(italics = wip)**

## pods

pods are configured in <pod_name>/pod.yaml following the k8s yaml implementation in podman. further, pods are semantically distinguished:

- michel - protection: http-reverse-proxy, wireguard; 
- frangisk - public service: photography, weblog;  
- _eligius - git: git-ssh, cgit;_
- _isidore - nas: nas-ganesha;_
- _gavrilo - cctv;_
- _akitio - server, backup, little-a-map;_
- _genesius - radarr etc.._
- _cecilia - music;_

### containers

- michel-http-reverse-proxy: a simple reverse proxy in caddy;
- frangisk-photography: my photography portfolio;
- frangisk-weblog: my blog;
- eligius-git-ssh: a simple ssh server to interact with git;
- eligius-cgit: a simple frontend to view the repo directory -- with http clone;
- _isidore-nas-ganesha: zfs;_
- akitio-server;
- _akitio-backup: using borg, borgmatic (configure borg);_
- _akitio-little-a-map;_

## images

### lighttpd: a generic lighttpd server
use launch parameters: `-D -f /etc/lighttpd/lighttpd.conf"`. the server serves whatever is at `/var/www/html`, and requires /var/lighttpd.conf to be defined as follows:
```
server.tag="this-is-a-tag"
server.port=8080
```

### git-ssh: a simple ssh server limited to git-shell-commands `ls` `mk <repo>` and `rm <repo>`. 
the default directory is /home/git/repos (as defined in git-shell-commands), I would suggest mounting your repo directory here. Additionally, following the ssh standard, `/home/git/.ssh/authorized_keys` will be read.

### cgit: a modified lighttpd image serving cgit
all definitions must be done as the lighttpd image, with the addition of a cgitrc which must be mounted to `/etc/cgitrc`

### caddy-reverse-proxy
a `Caddyfile` must be mounted to `etc/caddy/Caddyfile/`

## todo
- separate network namespaces for containers (currently per-pod, make per-container);
- static site gen for blog need to add --prefix option for all links (in this case /blog/);

- akitio-server;
- akitio-backup (borg vs zfs? unfortunately i dont think git-lfs would work, but id prefer it to stay with the same "versioning");
- akitio-little-a-map;
- akitio attach to console (stdin & tty), then decide whether to ssh into it or use an online term hosted akitio-webterm to interact. ssh more minimal, i doubt i need to access akitio from a webterm often;

- cgit private directory;
- cgit hide index.cgit from url (rewrite instead of redirect but not working?);
- cgit regarding above (currently) redirect, i am regex matching for paths NOT containing " . ", which fucks up for files like fabric.json;
- cgit fix about-formatting, its 404ing (its detecting the README tho);
- cgit fix http cloning, currently trying http://x.x.x.x/git/dots (which redirects to /git/index.cgi/dots, idk if it should?);
- cgit releases (binaries) (might need to code extension myself);
- git-ssh NOTE git-lfs-transfer will be required on the client to use lfs-over-ssh;
