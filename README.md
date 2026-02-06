# pluto
my personal homelab completely based on alpine and podman. all images are created by me.

## modules
containers are organised into functional modules based on responsibility and purpose. podman pods were considered for grouping, however, they were avoided to minimise attack surface and allow fine-grained per-container network and privilege isolation. pods enforce shared namespaces (network, IPC, and optionally PID) across all member containers, which is often not necessary. this approach keeps containers semantically grouped while preserving runtime isolation, flexible networking, and selective cooperation, rather than imposing rigid coupling through pods.

### michel
the `michel` module acts as the semantic gateway for all external access. all external traffic is intended to flow through michel into the `privat` and `public` networks, where a wireguard VPN and an HTTP/TCP reverse-proxy handle routing, respectively. (in the future, i would like to move `reverse-proxy-edge` to an external server to mask my homelab.)
**containers**: `reverse-proxy-edge`; `reverse-proxy-stats` (go access); `vpn-edge`.

### frangisk
the `frangisk` module contains all my webpages intended for access on the `public`.
**containers**: `lbmt-darkroom`; `lbmt-weblog`; `lbmt-shop`.

### eligius
the `eligius` module provides ssh-access git hosting for a repository pool via the `privat` network, and a read-only web interface via the `public` network.
**containers**: `git-ssh`; `git-web`.

### isidore
the `isidore` module handles access to my datastore, intitled `master` and mounted via a bind-mount. ssh-access and a web explorer (`filestash`) are provided via the `privat` network. it is expected to treat this datastore with a git-like paradigm, where edits are done on localised copies, and pushed via `rsync`, such that any device connected acts as a satellite. for accessible editing of the datastore, it can be mounted using `sftp`. 

i am still considering add a  `nas-nfs-ganesha` container to mount the storage on my PC. because, as is, both my PC and laptop are satellites of my server. this leads to have potentially having 3 copies of the same data. if this data is volatile (i.e. edited a lot), it can get messy to track which is the most up to date. if i mount the nas via `nfs` on my PC, the laptop becomes a satellite of my PC. this reduces the possible number of copies to 2. but at the end, i only have 2 working copies, regardless if i use nfs-ganesha or not.

(personal system note: the datastore is a zfs pool on a primary m.2 ssd for active data, secured with native zfs encrpytion. data integrity and disaster recovery are managed through an automated "pull-only" backup architecture, where a separate high capacity hdd pool remains logically isolated and is never exposed to sftp or nfs. a sanoid or zrepl (TBA) container manages point-in-time snapshots and executes incremental zfs send/receive operation. to prevent performance degradation, a retntion policy keeps the ssd pool below 80% capacity by pruning old snapshots.)
**containers**: `master-ssh`; `master-explorer-web`; `master-backup`.

### akitio
the `akitio` module manages my personal modded minecraft world of the same name. access to the server and a map of the world are provided via the `public` network. a web-terminal to admin the server is available via the `privat` network. a backup system is run locally, i.e. there is no way to access it over WAN.
**containers**: `minecraft-server`; `minecraft-ttyd-rcon`; `minecraft-map`; `minecraft-backup`.

### cecilia
the `cecilia` module serves a music server exposing the `opensubsonic` api and `navidrome` api, which is accessible via the `privat` network. further, a web client is also accessible via the `privat` network.
**containers**: `navidrome-server`; `navidrome-web-client`.

### gavrilo
prospective name for cctv server

### genesius
prospective name for radarr etccc, but im unsure. all netns owned in michel

| container             | module   | depends on             | named-volume mounts          | host-bind mounts                        | notes
| --------------------- | -------- | ---------------------- | ---------------------------- | --------------------------------------- | ------------------------------------------ |
| `reverse-proxy-edge`  | michel   |                        |                              |                                         |                                            |
| `vpn-edge`            | michel   |                        |                              |                                         |                                            |
| `lbmt-darkroom`       | frangisk |                        |                              |                                         | working tree of static site built into image |
| `lbmt-weblog`         | frangisk |                        |                              |                                         | working tree of static site built into image |
| `lbmt-shop`           | frangisk |                        | `lbmt-shop-database`         |                                         | working tree of site baked into image      |
| `lbmt-shop-backup`    | frangisk | `lbmt-shop`            | `lbmt-shop-database`         | `/zfs/storage/fotografija/shop`         |                                            |
| `git-ssh`             | eligius  |                        |                              | `/zfs/storage/git`                      |                                            |
| `git-web`             | eligius  |                        |                              | `/zfs/storage/git`                      |                                            |
| `master-ssh`          | isidore  |                        |                              | `/zfs/storage`                          |                                            |
| `master-explorer-web` | isidore  |                        |                              | `/zfs/storage`                          |                                            | 
| `master-backup`       | isidore  |                        |                              | `/zfs/storage`, `/zfs/backup`           |                                            |
| `minecraft-server`    | akitio   |                        | `mc-rcon`, `mc-working-tree` |                                         |                                            |
| `minecraft-ttyd-rcon` | akitio   | `minecraft-server`     | `mc-rcon`                    |                                         |                                            |
| `minecraft-map`       | akitio   | `minecraft-server`     | `mc-working-tree`            |                                         |                                            |
| `minecraft-backup`    | akitio   | `minecraft-server`     | `mc-rcon`, `mc-working-tree` | `/zfs/storage/loghob/minecraft/akitio/world`|                                        |
| `navidrome-server`    | cecilia  |                        |                              | `/zfs/storage/muzika/library`           |                                            |
| `navidrome-web-client`| cecilia  | `navidrome-web-client` |                              |                                         | using direct veth-pair to communicate w/ navidrome-server |


## images

### localhost/wireguard
(`nft add rule ip filter forward iif "vpn-edge" oif "vpn-edge" drop`) # make sure to enable host<->michel forwarding.

### localhost/lighttpd: a generic lighttpd server
use launch parameters: `-D -f /etc/lighttpd/lighttpd.conf"`. the server serves whatever is at `/var/www/html`, and requires /var/lighttpd.conf to be defined as follows:
```
server.tag="<tag>"
server.port=<port>
```

### localhost/git-ssh: a simple ssh server 
limited to git-shell-commands `ls` `mk <repo>` and `rm <repo>`.
the default directory is /home/git/repos (as defined in git-shell-commands), I would suggest mounting your repo directory here. Additionally, following the ssh standard, `/home/git/.ssh/authorized_keys` will be read. supports git-lfs! requires X package on client.

### localhost/cgit: a modified lighttpd image serving cgit
all definitions must be done as the lighttpd image, with the addition of a cgitrc which must be mounted to `/etc/cgitrc`.

- cgit private directory?;
- cgit hide index.cgit from url (rewrite instead of redirect but not working?);
- cgit regarding above (currently) redirect, i am regex matching for paths NOT containing " . ", which fucks up for files like fabric.json;
- cgit fix about-formatting, its 404ing (its detecting the README tho);
- cgit fix http cloning, currently trying http://x.x.x.x/git/dots (which redirects to /git/index.cgi/dots, idk if it should?);
- cgit releases (binaries) (might need to code extension myself);
- cgit some tabs are broken for large repos; try adding `scan_limit=1000000 max_objects=1000000` to the config. also can try shallow clones for web display, if the repo is huge, maybe only `--depth=50` recent commits show.

### localhost/caddy-reverse-proxy
a `Caddyfile` must be mounted to `etc/caddy/Caddyfile/`. logging is enabled via 
```    log {
        output file /var/log/caddy/access.log
        format json
    }
```

### localhost/minecraft-server
simply provides a Java OpenJdk 21 environment exposing port 25565. working-tree is found in a named volume mount for persistence. before every launch, `check-working-tree.sh` confirms it is up to date with the origin, and if not, will update. the world will also be in this named volume mount, and therefore this image ideally should not ever be mounted with a host bind mount, for security purposes. my system uses borg in another container which mounts the named volume containing the server+world, and backups the world to my `/zfs/storage`.

the server is whitelisted, but it is offline-mode. therefore, i was thinking to make a firewall ip whitelist for this container (or do it in the tcp reverse proxy). theres also the option to get players to use DDNS in their router, which would allow me automatically resolve their hostnames and updated the allowed IPs (dynamic ip shenanigans). 

### localhost/minecraft-ttyd-rcon
using rcon cli, ttyd and a wrapper script to show a web-terminal with direct access to the msg server, showing all logs of the current session and taking any command. it communicates to the mc server via a socat socket at /tmp/rcon.sock. this is to avoid opening any networking connections between a private container and a public container, and rcon only talks in tcp. /tmp/rcon.sock is found on a named volume.

### localhost/minecraft-backup
using borg, the container wil have a cron insider that executed backup.sh once a day. it will communicate to the server via the rcon.sock in the `rcon` named volume mount using socat. this is so the server can stop writing to the world, until borg is done backing it up. this is done to avoid corrupted or half written files. 

### localhost/minecraft-map
based on the lighttpd (maybe i dont even need make an image, and just use the lighttpd image i made. the point is, it will mount the named volume mount where the working-tree and world is. if it detects a change in the world maps folder, it will run the little-a-map binary to render the new map. the lighttpd server automatically updates.
```
#!/usr/bin/env bash

LAST_RUN=0
mkdir -p "$TMP_PATH"

while true; do
    inotifywait -r -e modify,create,delete,move "$WORLD_PATH"
    NOW=$(date +%s)
    ELAPSED=$(( NOW - LAST_RUN ))

    if [ $ELAPSED -ge $DEBOUNCE ]; then
        echo "$(date) - Changes detected, rendering map..."
        little-a-map "$WORLD_PATH" "$TMP_PATH"
        rsync -a --delete "$TMP_PATH"/ "$OUTPUT_PATH"/
        echo "$(date) - Map updated."
        LAST_RUN=$NOW
    else
        REM=$((DEBOUNCE - ELAPSED))
        echo "$(date) - Change detected but still within debounce period ($REM s remaining)."
    fi
done
```
```
# Disable caching for all map tiles
$HTTP["url"] =~ "\.(png|jpg|jpeg|webp|svg)$" {
    setenv.add-response-header = (
        "Cache-Control" => "no-store, no-cache, must-revalidate",
        "Pragma"        => "no-cache",
        "Expires"       => "0"
    )
}
```

## to look into/notes
- users/owners
- when mounting, prioritise read-only volumes. use named volumes instead of host bind mounts if persistence is needed.
- reduce root privileges such as CAP_SYS_ADMIN; CAP_NET_ADMIN; CAP_SYS_MODULE. (list enabled privileges: `podman run --rm alpine capsh --print | grep Bounding`);
- `cat /sys/kernel/security/apparmor/profiles` apparmor enabled if returns anything; `podman run --rm alpine grep Seccomp /proc/self/status` "Seccomp: 2" means a filter is active (the default one). real test: `podman run --rm alpine reboot`. logs: `dmesg | grep -iE "audit|apparmor|seccomp"`
- change ports, passwords etc... compared to github repo.
- static site gen for blog need to add --prefix option for all links (in this case /blog/);
- git check if a git user (instead of liam) would be good for eligius. (i dont think so as podman is running under liam);
- git-ssh NOTE git-lfs-transfer will be required on the client to use lfs-over-ssh;
- reverse-proxy statistics
- make images more secure using a builder-runtime (and maybe distroless runtime)
- view user-space network interfaces (netavark) - `doas nsenter -t $(pgrep -u $USER podman) -n ip link` (what is this?)

## networking
this network architecture utilises a dual-hub, zero-trust model to enforce strict lateral isolation between containers, which unless is required, is usually done via `socat` or opening a `veth` between the appropriate containers. additionally, standard container bridge networking is bypassed in favour of manual `veth` pair injection directly into container network namespaces, which eliminate the host-level gateway and the associated risk of inter-container leaks, common in flat network. containers are segmented into two distinct "hub", a `privat` network (via `vpn-edge`), and a `public` network (via `reverse-proxy-edge`). this is where communication is restricted to point-to-point virtual links using `/30` subnets.

the Alpine host functions as a silent switchboard; because interfaces are moved into namespaces, the host routing table remains pristine and unexploitable. this is also paired with granular traffic control, as each connection is a dedicated "virtual wire," precise `nftables` filtering is done at the network level rather than relying on broad, automated firewall rules.

### topology

the network is invariant, i.e. the host does not route between containers. all WAN routing occurs inside the michel namespace, and container-container routing happens directly between them. a /31 subnet is being used as each veth interface exclusively acts point-to-point, therefore, there is no l2 bridging in `reverse-proxy-edge` and `vpn-edge`. all routes are exhaustively listed in the table below.

| veth interface name         | endpoint A           | endpoint A ip   | endpoint B             | endpoint B ip   | subnet             |
| --------------------------- | -------------------- | --------------- | ---------------------- | --------------- | ------------------ |
| `host-pub`                  | `host`               | `192.168.100.0` | `reverse-proxy-edge`   | `192.168.100.1` | `192.168.100.0/31` |
| `host-priv`                 | `host`               | `192.168.101.0` | `vpn-edge`             | `192.168.101.1` | `192.168.101.0/31` |
| `pub-lbmt-darkroom`         | `reverse-proxy-edge` | `172.16.1.0`    | `lbmt-darkroom`        | `172.16.1.1`    | `172.16.1.0/31`    |
| `pub-lbmt-weblog`           | `reverse-proxy-edge` | `172.16.2.0`    | `lbmt-weblog`          | `172.16.2.1`    | `172.16.2.0/31`    |
| `pub-lbmt-shop`             | `reverse-proxy-edge` | `172.16.3.0`    | `lbmt-shop`            | `172.16.3.1`    | `172.16.3.0/31`    |
| `priv-git-ssh`              | `vpn-edge`           | `10.1.1.0`      | `git-ssh`              | `10.1.1.1`      | `10.1.1.0/31`      |
| `pub-git-web`               | `reverse-proxy-edge` | `172.16.4.0`    | `git-web`              | `172.16.4.1`    | `172.16.4.0/31`    |
| `priv-master-ssh`           | `vpn-edge`           | `10.1.2.0`      | `master-ssh`           | `10.1.2.1`      | `10.1.2.0/31`      |
| `priv-master-explorer-web`  | `vpn-edge`           | `10.1.3.0`      | `master-explorer-web`  | `10.1.3.1`      | `10.1.3.0/31`      |
| `pub-minecraft-server`      | `reverse-proxy-edge` | `172.16.5.0`    | `minecraft-server`     | `172.16.5.1`    | `172.16.5.0/31`    |
| `priv-minecraft-ttyd-rcon`  | `vpn-edge`           | `10.1.4.0`      | `minecraft-ttyd-rcon`  | `10.1.4.1`      | `10.1.4.0/31`      |
| `pub-minecraft-map`         | `reverse-proxy-edge` | `172.16.6.0`    | `minecraft-map`        | `172.16.6.1`    | `172.16.6.0/31`    |
| `priv-navidrome-server`     | `vpn-edge`           | `10.1.5.0`      | `navidrome-server`     | `10.1.5.1`      | `10.1.5.0/31`      |
| `priv-navidrome-web-client` | `vpn-edge`           | `10.1.6.0`      | `navidrome-web-client` | `10.1.6.1`      | `10.1.6.0/31`      |
| `navidrome-server-client`   | `navidrome-server`   | `10.254.1.0`    | `navidrome-web-client` | `10.254.1.1`    | `10.254.1.0/31`    |

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
   │   ↳ logging                               │
   │   ↳ rate limiting                         │
   └─────────────────────┬─────────────────────┘
                     ┌───┴─────────────────────────┐
         +-----------▼-----------+     +-----------▼-----------+
         | Host Bridge Interface |     | Host Bridge Interface |
         |  (network `privat`)   |     |   (network `public`)  |
         +-----------┬-----------+     +-----------┬-----------+
                     └┐                           ┌┘
       +--------------┼---------------------------┼--------------+
       |              │       module michel       │              |
       |  ┌───────────▼───────────┐   ┌───────────▼───────────┐  |
       |  │ WireGuard VPN (tun0)  │   │ Reverse Proxy (Caddy) │  |
       |  ╞═══════════════════════╡   ╞═══════════════════════╡  |
       |  │ + psk                 │   │ + hsts                │  | X-Frame-Options, X-Content-Type, Permissions-Policy (disable cam/mic)
       |  │ + key pairs           │   │ + security headers    │  |
       |  │   ↳ use pam_mount     │   │ + rate limiting       │  |
       |  │     or yubikey        │   │ + GET/POST/HEAD only  │  |
       |  │     or phone HSM      │   │ + header_down         │  |
       |  └───────────┬───────────┘   └───────────┬───────────┘  |
       +--------------┼---------------------------┼--------------+
                    ┌─┘                          ┌┘
    +---------------┼----------------------------┼--------------------------------------------+
    |               │     networks               │                                            |
    |  +------------▼------------+  +------------▼------------+  +-------------------------+  |
    |  | private                 |  | public                  |  | networkless             |  |
    |  ├-------------------------┤  ├-------------------------┤  ├-------------------------┤  |
    |  | ┌───────────────────────┼──┼─────────────────────────┼──┼───────────────────────┐ │  |
    |  | │                                 module akitio                                 | │  |
    |  | ╞═══════════════════════╬══╬═════════════════════════╬══╬═══════════════════════╡ |  |
    |  | │ + minecraft-ttyd-rcon |  | + minecraft-server      │  | + minecraft-backup    | |  |
    |  | │                       |  | + minecraft-map         │  |                       | |  |
    |  | └───────────────────────┼──┼─────────────────────────┼──┼───────────────────────┘ |  |
    |  | ┌───────────────────────┼──┼───────────────────────┐ │  |                         │  |
    |  | │                   module eligius                 | │  |                         │  |
    |  | ╞═══════════════════════╬══╬═══════════════════════╡ │  |                         |  |
    |  | │ + git-ssh             |  | + cgit-web            │ │  |                         |  |
    |  | └───────────────────────┼──┼───────────────────────┘ │  |                         |  |
    |  | ┌─────────────────────┐ |  |                         |  |                         |  |
    |  | │ module isidore      │ |  |                         |  |                         |  |
    |  | ╞═════════════════════╡ |  |                         |  |                         |  |
    |  | │ + nas-sftp          │ |  |                         |  |                         |  |
    |  | └─────────────────────┘ |  |                         |  |                         |  |
    |  |                         |  | ┌─────────────────────┐ |  |                         |  |
    |  |                         |  | │ pod frangisk        │ |  |                         |  |
    |  |                         |  | ╞═════════════════════╡ |  |                         |  |
    |  |                         |  | │ + darkroom          │ |  |                         |  |
    |  |                         |  | │ + weblog            │ |  |                         |  |
    |  |                         |  | └─────────────────────┘ |  |                         |  |
    |  +-------------------------+  +-------------------------+  +-------------------------+  |
    +-----------------------------------------------------------------------------------------+
```
### routing
```
                              Internet (WAN)
                                   │
                         +---------▼---------+
                         |     Host eth0     |   <-- physical network interface (LAN/WAN)
                         +---------┬---------+
                        ┌──────────┴──────────┐                     
                +-------▼-------+ OR  +-------▼-------+
                |   host-priv   |     |   host-pub    |   <-- veth pairs between host and michel
                +-------┬-------+     +-------┬-------+
                   ┌────┘                     └────┐                     
     +-------------▼-------------+   +-------------▼-------------+
     |     vpn-edge (tun0)       |   | reverse-proxy-edge (eth0) |   <-- veth interfaces in module michel
     +-------------┬-------------+   +-------------┬-------------+
                   │                               │
     +-------------▼-------------+   +-------------▼-------------+
     |      priv-container1      |   |       pub-container2      |   <-- veth pairs between michel and other container
     +-------------┬-------------+   +-------------┬-------------+
                   │                               │
       +-----------▼-----------+       +-----------▼-----------+
       |   container 1 (eth0)  |       |   container 2 (eth0)  |   <-- veth interfaces inside other containers
       +-----------------------+       +-----------------------+
```

## security

my threat model is...

### apparmor & seccomp
the host only has 1 apk: Podman. therefore, the attack surface is extremely small, and a simple profile will suffice (/etc/apparmor/host.profile). 

however, a few small additions for my system have been added:
- `/zfs/storage` blacklisted;
- need to check if i can disable containers from making their own networks

### nftables
`reverse-proxy blocks SSH, VPN, everything else besides HTTP(S) and MINECRAFT TCP? maybe, by default, blacklist *, whitelist some in containers: 
```
#!/usr/sbin/nft -f

table inet filter {
    chain input {
        type filter hook input priority 0;
        policy drop;

        # allow loopback
        iif lo accept

        # allow established/related connections
        ct state established,related accept

        # everything else is dropped
    }

    chain forward {
        type filter hook forward priority 0;
        policy drop;
    }

    chain output {
        type filter hook output priority 0;
        policy accept;
    }
}
```

### fail2ban
i think its best to run it on host, to protect from bandwidth dos attacks. the issue is, it needs to see caddy logs to see who's attacking. coz if i put it into `reverse-proxy-edge` container, it will successfully protect the container and other public containers from attacks, but not the host. (i think at least).

## out of band kvm
a mobo with aspeed bmc or an external pkivm/nanokvm will allow the system to have an out of band management layer, that operates entirely independently of the host os and primary network stack. the kvm interfacxe is physically isolated on a dedicated management port and only accessible through a strictly firewalled vpn tunnel on my openwrt router.
