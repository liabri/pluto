# pluto
my personal homelab completely based on alpine and podman. all images are created by me. **(italics = wip)**

## pods

pods are configured in <pod_name>/pod.yaml following the k8s yaml implementation in podman. further, pods are semantically distinct:

- michel - protection: http-reverse-proxy, wireguard;
- frangisk - public service: photography, weblog;
- _eligius - git: git-ssh, cgit;_
- _isidore - nas: nas-ganesha;_
- _gavrilo - cctv;_
- _akitio - minecraft-server, backup, little-a-map;
- _genesius - radarr etc.._
- _cecilia - music;_

### containers

- michel-http-reverse-proxy: a caddy reverse proxy facilitating access to the internal network 'public';
- michel-vpn: a wireguard vpn restricting access to the internal network 'private';
- frangisk-liambrincat: website 'liambrincat';
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

### minecraft-serveraw
simply provides a headless Java OpenJdk 21 environment exposing port 25565

## todo
- separate network namespaces for containers (currently per-pod, make per-container);
- static site gen for blog need to add --prefix option for all links (in this case /blog/);

- akitio-server (on launch updates to latest akitio-server git repo locally (can do it through the git server, but unless I introduce hooks, there is no need);
- akitio-backup (borg vs zfs? unfortunately i dont think git-lfs would work, but id prefer it to stay with the same "versioning");
- akitio-little-a-map;
- akitio attach to console (stdin & tty) then ssh into container to control.

- git check if a git user (instead of liam) would be good for eligius. (i dont think so as podman is running under liam);
- cgit private directory;
- cgit hide index.cgit from url (rewrite instead of redirect but not working?);
- cgit regarding above (currently) redirect, i am regex matching for paths NOT containing " . ", which fucks up for files like fabric.json;
- cgit fix about-formatting, its 404ing (its detecting the README tho);
- cgit fix http cloning, currently trying http://x.x.x.x/git/dots (which redirects to /git/index.cgi/dots, idk if it should?);
- cgit releases (binaries) (might need to code extension myself);
- cgit some tabs are broken for large repos;
- git-ssh NOTE git-lfs-transfer will be required on the client to use lfs-over-ssh;

- reverse-proxy statistics

## cheatsheet

list pods - podman pod ps
start pod - doas rc-service pod-{name} start
view user-space network interfaces (netavark) - `doas nsenter -t $(pgrep -u $USER podman) -n ip link`

## to look into
users/owners
selinux
apparmor
fail2ban
nftables


custom networking (no dns - assign manually)

strip shared namespace from semantics of pod OR introduce new semantic level above called service groups. must be separated network namespace for security:
wireguard and caddy;
akitio server and backup;

currently:
ip:port
pod-namespace-address:container's-exposed-port



networking good security practices:
	D isolated networks;
	D nftables on host;
	D wireguard for private network;
	remove podman bridge access for all pods besides michel

file system good security practices:
	volume mounts:
		dont mount any sensitive directories;
		use read-only mounts when possible;
		use named volumes or container-local storage when persistent data is needed, instead of host bind mounts;
	namespaces:
		use separate PID, User and Mount namespaces;
		D rootless containers;
	capabilities:
		reduce root privileges such as CAP_SYS_ADMIN; CAP_NET_ADMIN; CAP_SYS_MODULE;
		seccomp profiles, apparmor and selinux policies to confine container permissions;



ALL MY PROBLEMS LIE AT THE FAULT OF kube plays yaml, it lacks stdin/tty, and cannot give a container inside a pod its own network namespace (i think).



from wan, you can:

read-only the cpu temperature, gpu temperature, disk usage, ram usage, uptime, network traffic, containers logs (wireguard, caddy, host)


## networking

\pagebreak
### topology
```
                    Internet (WAN)
                         │
       ┌─────────────────▼─────────────────┐
       │               Router              │────────────────┐
       ╞═══════════════════════════════════╡     ┌──────────▼──────────┐
       │ + OpenWrt (IDS/IPS)               │     │ IPMI/BMC Interface  │
       │   ↳ 'admin' vpn w/ port knocking  │     ╞═════════════════════╡
       └─────────────────┬─────────────────┘     │ + read-write admin  │
   ┌─────────────────────▼─────────────────────┐ │   ↳ mac policy      │
   │                Host (eth0)                │ │   ↳ firewall        │
   ╞═══════════════════════════════════════════╡ │   ↳ zfs rollbacks   │
   │ + apparmor                                │ │   ↳ container state │
   │ + nftables                                │ └──────────┬──────────┘
   │   ↳ zero-trust                            ◀────────────┘
   │   ↳ inter-container traffic filtering     │
   │   ↳ VPN ACLs                              │
   │   ↳ logging                               │
   │   ↳ rate limiting                         │
   └─────────────────────┬─────────────────────┘
                     ┌───┴─────────────────────────┐
         +-----------▼-----------+     +-----------▼-----------+
         | Host Bridge Interface |     | Host Bridge Interface |
         |   (private network)   |     |    (public network)   |
         +-----------┬-----------+     +-----------┬-----------+
                     └┐                           ┌┘
       +--------------┼---------------------------┼--------------+
       |              │       pod michel          │              |
       |  ┌───────────▼───────────┐   ┌───────────▼───────────┐  |
       |  │ WireGuard VPN (tun0)  │   │ Reverse Proxy (Caddy) │  |
       |  ╞═══════════════════════╡   ╞═══════════════════════╡  |
       |  │ + encrypted w/ keys   │   │ + https               │  |
       |  │ + port knocking on a  │   │ + security headers    │  |
       |  │   random port         │   │ + rate limiting       │  |
       |  │ + kill switch         │   │ + GET/POST/HEAD only  │  |
       |  │ + client ACLs         │   │ + header_down         │  |
       |  └───────────┬───────────┘   └───────────┬───────────┘  |
       +--------------┼---------------------------┼--------------+
                    ┌─┘                           └─┐
    +---------------┼-------------------------------┼---------------+
    |               │     network namespace         │               |
    |  +------------▼------------+     +------------▼------------+  |
    |  | private pods            |     | public pods             |  |
    |  ├-------------------------┤     ├-------------------------┤  |
    |  | ┌─────────────────────┐ |     | ┌─────────────────────┐ |  |
    |  | │ pod akitio          │ |     | │ pod frangisk        │ |  |
    |  | ╞═════════════════════╡ |     | ╞═════════════════════╡ |  |
    |  | │ + minecraft-server  │ |     | │ ↳ AppArmor          │ |  |
    |  | │ + little-a-map      │ |     | │ ↳ seccomp           │ |  |
    |  | │ + borg-backup       │ |     | │ ↳ read-only         │ |  |
    |  | └─────────────────────┘ |     | │ ↳ least privelages  │ |  |
    |  | ┌─────────────────────┐ |     | └─────────────────────┘ |  |
    |  | │ + borg-backup       │ |     +-------------------------+  |
    |  | │ pod eligius         │ |                                  |
    |  | ╞═════════════════════╡ |                                  |
    |  | │ + git-ssh           │ |                                  |
    |  | │ + cgit-web          │ |                                  |
    |  | └─────────────────────┘ |                                  |
    |  | ┌─────────────────────┐ |                                  |
    |  | │ pod isidore         │ |                                  |
    |  | ╞═════════════════════╡ |                                  |
    |  | │ + nas               │ |                                  |
    |  | └─────────────────────┘ |                                  |
    |  | ┌─────────────────────┐ |                                  |
    |  | │ pod gavrilo         │ |                                  |
    |  | ╞═════════════════════╡ |                                  |
    |  | │ ↳ read-only         │ |                                  |
    |  | │ + cctv              │ |                                  |
    |  | └─────────────────────┘ |                                  |
    |  +-------------------------+                                  |
    +---------------------------------------------------------------+
```

\pagebreak
### simple network

```
                          Internet (WAN)
                                │
                      +---------▼---------+
                      |    Host eth0      |   <-- Physical network interface (LAN/WAN)
                      +---------┬---------+
                                │
                      +---------▼----------+
                      |   Bridge Interface |  (e.g. podman1)
                      +----┬---------┬-----+
                           │         │
             +-------------▼-+    +--▼-------------+
             |     vethX     |    |     vethY      |   <-- veth pairs (host side)
             +---------------+    +----------------+
                   │                      │
             +-----▼-----+          +-----▼-----+
             |   eth0    |          |   eth0    |   <-- Container interfaces
             |  (pod1)   |          |  (pod2)   |
             +-----------+          +-----------+
```

\pagebreak
### routing traffic through a vpn or reverse proxy in pod-michel
```
                          Internet (WAN)
                              │   ▲
					  +-------▼---┴-------+
                      |    Host (eth0)    |
                      +-------┬---▲-------+
                              │   │
					  +-------▼---┴-------+
                      |       bridge      |
                      +-------┬---▲-------+
                              │   │
					  +-------▼---┴-------+
					  |      (veth0)      |
                      +-------┬---▲-------+
                              │   │
					  +-------▼---┴-------+
					  | wireguard  (tun0) | (or reverse proxy)
                      +-------┬---▲-------+
                              │   │
					  +-------▼---┴-------+
					  |      (veth1)      |
                      +-------┬---▲-------+
                              │   │
					  +-------▼---┴-------+
					  | pod akitio (eth0) |
					  +-------------------+
 ```
