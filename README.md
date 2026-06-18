# pluto
my personal homelab completely based on nixos and podman with custom-authored images. the architecture is strictly governed by a two-part physical and logical paradigm: The Storage Foundation (State) and The Application Runtime (Stateless compute). the physical storage is respectively split between a logically isolated ZFS mirror pool and an ephemeral ext4 OS drive.

## part I: the source of truth (state)

all persistent data and backups live exclusively on a mirrored zfs pool of high-capacity HDDs, hereafter referred to as the `datastore`. this pool acts as the system's Single Source of Truth (SoT). it guarantees data integrity and disaster recovery natively through hardware ECC memory validation and automated host-level zfs snapshots.

internally, the datastore is not organized by standard folders, but by distinct zfs datasets (e.g., git, games, etc.). this logical segregation allows tuning specific filesystem properties, such as compression algorithms, record sizes, and snapshot retention policies, to perfectly match the distinct nature of the data residing within each dataset.

**table 1: datasets**
| dataset                    | refquota | quota | recordsize | compression | canmount | access | data_type | purpose & contents     | 
| -------------------------- | -------- | ----- | ---------- | ----------- | -------- | ------ | --------- | ---------------------- | 
| /mahzen/muzika             | 270G     | 300G  | 1M         | off         | on       | ro*    | immutable | music library (.flac)  |
| /mahzen/ritratti           | 90G      | 100G  | 1M         | lz4         | on       | ro*    | immutable | photos                 |
| /mahzen/doc                | 10G      | 20G   | 128K (def) | zstd        | on       | rw     | volatile  | .griss or .typst       |
| /mahzen/git                | 50G      | 100G  | 128K (def) | zstd        | on       | rw     | volatile  | bare git repo          |
| /mahzen/loghob             | N/A      | N/A   | 1M         | lz4         | off      |        |           | parent games set       |
| /mahzen/loghob/cold        | 1.8T     | 2T    | 1M         | zstd-9      | on       | ro*    | bulk      | game files             |
| /mahzen/loghob/hot         | 10G      | 20G   | 64K        | lz4         | on       | rw     | volatile  | game profiles          |
| /mahzen/fotografija        | N/A      | N/A   | 64K        | lz4         | off      |        |           | parent photography set |
| /mahzen/fotografija/hot    | 50G      | 100G  | 64K        | lz4         | on       | rw     | volatile  | photography edits      |
| /mahzen/fotografija/cold   | 80G      | 100G  | 1M         | zstd-9      | on       | ro*    | immutable | photography raws       |

* datasets may be temporarily unlocked for 15 minutes for writing purposes via scriptbins defined in `configuration.nix`.
global datastore properties: `xattr=sa`; `acltype=posixacl`; `snapdir=visible`; `atime=off`.

the hot/cold split (such as `/mahzen/loghob/cold` and `/mahzen/loghob/hot`) isolates fundamentally opposing datasets to maximize performance, security, and scalability. structurally, volatile `hot` data demands small blocks (64K) and aggressive snapshots, while immutable `cold` data requires massive blocks (1M) and heavy compression. this strict boundary prevents snapshot bloat and confines copy-on-write fragmentation to active databases, ensuring cold media always streams at peak sequential speeds. semantically, it enables a WORM security model: cold archives are locked read-only at the ZFS kernel level against ransomware, while hot sets remain fluid. operationally, this split unlocks asymmetric backup strategies, syncing hot configurations hourly and massive media monthly, and frictionless hardware tiering.

additionally, to prevent split-brain scenarios, where multiple devices hold competing, desynced data, the architecture strictly minimizes local copies. this specifically targets `/mahzen/fotografija/hot` and `/mahzen/loghob/hot`, since other volatile datasets are either natively version-controlled (`/mahzen/git`) or accessed exclusively via web interfaces (`/mahzen/doc`). client access is dictated by mobility: fixed LAN devices (desktops) interact entirely via SFTP mounts with zero local footprint. conversely, roaming devices (laptops, phones) utilise SFTP strictly to browse cold assets, relying on a local cache managed via `syncthing`. syncthing is a daemon running continuously in the background, seamlessly syncing changes peer-to-peer the moment a roaming device connects to a network, automatically preserving older files as conflict copies if simultaneous changes occur.

## part II: the ephemeral runtime (stateless)

the OS and all containerised applications and services run on a fast, primary SSD. this drive is treated as a strictly ephemeral, disposable runtime environment. no valuable persistent state lives here. containers execute on the SSD to maximize IOPS (e.g., for database queries and game servers), but read and write their state directly to the datastore via explicit bind-mounts. runtime write-access to the SoT is heavily restricted. where possible, containers receive read-only (:ro) access. furthermore, live "working trees" are isolated entirely on the SSD to air-gap public services from the HDD. for example, the darkroom website's bare git repository is locked safely on the datastore; upon a git push, a hook extracts the working tree to an SSD volume, which the web container then serves read-only. this ensures maximum NVMe speed and complete physical isolation.

all services run from /srv/<service>.

### modules
containers and services are organised into functional nix modules based on responsibility and purpose. this approach keeps containers and services semantically grouped while preserving runtime isolation, flexible networking, and selective cooperation.

container vs service

**table 2: containers**
| container       | module   | depends on      | named-volume mounts                       | host-bind mounts    | purpose                                      |
| --------------- | -------- | --------------- | ----------------------------------------- | ------------------- | -------------------------------------------- |
| `rproxy-edge`   | michel   |                 |                                           |                     | caddy reverse proxy                          |
| `vpn-edge`      | michel   |                 |                                           |                     | wireguard vpn                                |
| `lbmt-foto`     | frangisk | `rproxy-edge`   | `lbmt-foto-wt:ro`                         |                     | website photography portfolio                |
| `lbmt-shop`     | frangisk | `rproxy-edge`   | `lbmt-shop-wt:ro`<br>`lbmt-shop-database` |                     |                                              |
| `git-ssh`       | eligius  | `vpn-edge`      | `lbmt-foto-wt`<br>`lbmt-weblog-wt`        | `/mahzen/git:rw`    |                                              |
| `git-web`       | eligius  | `rproxy-edge`   |                                           | `/mahzhen/git:ro`   |                                              |
| `mc-server`     | akitio   | `rproxy-edge`   | `mc-rcon`<br>`mc-working-tree`            |                     |                                              |
| `mc-ttyd     `  | akitio   | `vpn-edge`<br>`mc-server`   | `mc-rcon`                     |                     |                                              |
| `mc-map`        | akitio   | `rproxy-edge`<br>`mc-server`| `mc-working-tree`             |                     |                                              |
| `mc-world-pull` | akitio   | `mc-server`     | `mc-working-tree` | `/mahzen/loghob/minecraft/akitio/world:ro`  |                                              |
| `navid-server`  | cecilia  | `vpn-edge`      |                                           | `/mahzen/muzika:ro` |                                              |
| `navid-web`     | cecilia  | `navid-web`     |                                           |                     |                                              |

**table 3: services**
| service         | module   | purpose                                         |
| --------------- | -------- | ----------------------------------------------- |
| `zfs-ssh`       | isidore  | ssh server for the whole server                 |
| `zfs-sftp`      | isidore  | enabled sftp in the above ssh server            |
| `zfs-sanoid`    | isidore  | handles sanoid snapshots                        |
| `mc-check-wt`   | akitio   | checks git status the working tree of mc-server |
| `zfs-sanoid`    | isidore  | handles sanoid snapshots                        |
| `apparmor`      |          | security                                        |
| `fail2ban`      |          | ban ips that fail too many times(?)             |

#### isidore
**containers**: `zfs-web`.
**services**: `zfs-sftp`; `zfs-sanoid`.

**table 4: sanoid snapshot retention policies**
| data_type | hourly | daily | weekly | monthly | 
| --------- | ------ | ----- | ------ | ------- |
| volatile  | 24     | 7     | 4      | 0       |
| immutable | 0      | 7     | 4      | 3       |
| bulk      | 0      | 0     | 0      | 0       |

#### michel
the `michel` module acts as the semantic gateway for all external access. all external traffic is intended to flow through michel into the `privat` and `public` networks, where a wireguard VPN and an HTTP/TCP reverse-proxy handle routing, respectively. (in the future, i would like to move `rproxy-edge` to an external server to mask my homelab.)
**containers**: `rproxy-edge`; `rproxy-stats` (go access); `vpn-edge`.
**services**: `fail2ban`; `nftables`.

##### nftables
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

#### frangisk
the `frangisk` module contains all my webpages intended for access on the `public`.
**containers**: `lbmt-foto`; `lbmt-weblog`; `lbmt-shop`.

#### eligius
the `eligius` module provides ssh-access git hosting for a repository pool via the `privat` network, and a read-only web interface via the `public` network. note that to separate the hdd / ssd effectively for modules like frangisk or akitio, i would need a way to keep working-trees of git repos updated. a post-receive hook is the way. in git repo: `git --work-tree=/var/ssd-volumes/lbmt-foto-wt checkout -f main`
**containers**: `git-ssh`; `git-web`.

#### akitio
the `akitio` module manages my personal modded minecraft world of the same name. access to the server and a map of the world are provided via the `public` network. a web-terminal to admin the server is available via the `privat` network. a backup system is run locally as a service, i.e. there is no way to access it over WAN.
**containers**: `mc-server`; `mc-ttyd`; `mc-map`; `mc-world-pull`.
**services**: `mc-check-wt`; `mc-borg-backup`.

#### veirnin
image server
**containers**: probably `immich`.

#### cecilia
the `cecilia` module serves a music server exposing the `opensubsonic` api and `navidrome` api, which is accessible via the `privat` network. further, a web client is also accessible via the `privat` network.
**containers**: `navid-server`; `navid-web`.

#### gavrilo
prospective name for cctv server

#### genesius
prospective name for radarr etccc, but im unsure. all netns owned in michel

### images

#### localhost/wireguard
(`nft add rule ip filter forward iif "vpn-edge" oif "vpn-edge" drop`) # make sure to enable host<->michel forwarding.

#### localhost/lighttpd: a generic lighttpd server
use launch parameters: `-D -f /etc/lighttpd/lighttpd.conf"`. the server serves whatever is at `/var/www/html`, and requires /var/lighttpd.conf to be defined as follows:
```
server.tag="<tag>"
server.port=<port>
```

#### localhost/git-ssh: a simple ssh server 
limited to git-shell-commands `ls` `mk <repo>` and `rm <repo>`.
the default directory is /home/git/repos (as defined in git-shell-commands), I would suggest mounting your repo directory here. Additionally, following the ssh standard, `/home/git/.ssh/authorized_keys` will be read. supports git-lfs! requires X package on client.

#### localhost/cgit: a modified lighttpd image serving cgit
all definitions must be done as the lighttpd image, with the addition of a cgitrc which must be mounted to `/etc/cgitrc`.

- cgit private directory?;
- cgit hide index.cgit from url (rewrite instead of redirect but not working?);
- cgit regarding above (currently) redirect, i am regex matching for paths NOT containing " . ", which fucks up for files like fabric.json;
- cgit fix about-formatting, its 404ing (its detecting the README tho);
- cgit fix http cloning, currently trying http://x.x.x.x/git/dots (which redirects to /git/index.cgi/dots, idk if it should?);
- cgit releases (binaries) (might need to code extension myself);
- cgit some tabs are broken for large repos; try adding `scan_limit=1000000 max_objects=1000000` to the config. also can try shallow clones for web display, if the repo is huge, maybe only `--depth=50` recent commits show.

#### localhost/caddy-reverse-proxy
a `Caddyfile` must be mounted to `etc/caddy/Caddyfile/`. logging is enabled via 
```    log {
        output file /var/log/caddy/access.log
        format json
    }
```

#### localhost/minecraft-server
simply provides a Java OpenJdk 21 environment exposing port 25565. working-tree is found in a named volume mount for persistence. before every launch, `check-working-tree.sh` confirms it is up to date with the origin, and if not, will update. the world will also be in this named volume mount, and therefore this image ideally should not ever be mounted with a host bind mount, for security purposes. my system uses borg in another container which mounts the named volume containing the server+world, and backups the world to my `/zfs/storage`.

the server is whitelisted, but it is offline-mode. therefore, i was thinking to make a firewall ip whitelist for this container (or do it in the tcp reverse proxy). theres also the option to get players to use DDNS in their router, which would allow me automatically resolve their hostnames and updated the allowed IPs (dynamic ip shenanigans). 

#### localhost/minecraft-ttyd
using rcon cli, ttyd and a wrapper script to show a web-terminal with direct access to the msg server, showing all logs of the current session and taking any command. it communicates to the mc server via a socat socket at /tmp/rcon.sock. this is to avoid opening any networking connections between a private container and a public container, and rcon only talks in tcp. /tmp/rcon.sock is found on a named volume.

#### localhost/minecraft-backup
using borg, the container wil have a cron insider that executed backup.sh once a day. it will communicate to the server via the rcon.sock in the `rcon` named volume mount using socat. this is so the server can stop writing to the world, until borg is done backing it up. this is done to avoid corrupted or half written files. 

#### localhost/minecraft-map
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

#### to look into/notes
- users/owners
- static site gen for blog need to add --prefix option for all links (in this case /blog/);

### networking
this network architecture utilises a dual-hub, zero-trust model to enforce strict lateral isolation between containers, which unless is required, is usually done via `socat` or opening a `veth` pair between the appropriate containers. additionally, standard container bridge networking is bypassed in favour of manual `veth` pair injection directly into container network namespaces, which eliminate the host-level gateway and the associated risk of inter-container leaks, common in flat network. containers are segmented into two distinct "hub", a `privat` network (via `vpn-edge`), and a `public` network (via `rproxy-edge`). this is where communication is restricted to point-to-point virtual links using `/30` subnets.

the Alpine host functions as a silent switchboard; because interfaces are moved into namespaces, the host routing table remains pristine and unexploitable. this is also paired with granular traffic control, as each connection is a dedicated "virtual wire," precise `nftables` filtering is done at the network level rather than relying on broad, automated firewall rules.

**table 2: networking responsibility matrix**
| connection path          | scope     | defined In        | method                         | access logic                                                                       |
| :----------------------- | :-------- | :---------------- | :----------------------------- | :--------------------------------------------------------------------------------- |
| satellite → lab (Local)  | Local LAN | `OpenWrt` (router)| static hostname / DNS override | the domain resolves to the internal host ip, directing users to `vpn-edge` or `rproxy-edge`. |
| satellite → lab (Remote) | WAN       | Public DNS        | standard A-Record / CNAMEs     | the domain resolves to the public home ip, directing users to `vpn-edge` or `rproxy-edge`. |
| container → container    | internal  | containers' netns | veth pairs                     | veth interfaces defined in containers' netns for a direct connection (see table 3).|
| internet → lab           | public    | Public DNS        | standard A-Record / CNAMEs     | directs the general public to `rproxy-edge` for public modules.                    |

### topology

the network is invariant, i.e. the host does not route between containers. all WAN routing occurs inside the michel namespace, and container-container routing happens directly between them. a /31 subnet is being used as each veth interface exclusively acts point-to-point, therefore, there is no l2 bridging in `rproxy-edge` and `vpn-edge`. all routes are exhaustively listed in the table below.

**table 3: veth pairs**
| veth interface name   | endpoint A     | endpoint A ip   | endpoint B      | endpoint B ip   | subnet |
| --------------------- | -------------- | --------------- | --------------- | --------------- | ------ |
| `host-pub`            | `host`         | `192.168.100.0` | `rproxy-edge`   | `192.168.100.1` | `/31`  |
| `host-pri`            | `host`         | `192.168.101.0` | `vpn-edge`      | `192.168.101.1` | `/31`  |
| `pub-lbmt-foto`       | `rproxy-edge`  | `172.16.1.0`    | `lbmt-foto`     | `172.16.1.1`    | `/31`  |
| `pub-lbmt-weblog`     | `rproxy-edge`  | `172.16.2.0`    | `lbmt-weblog`   | `172.16.2.1`    | `/31`  |
| `pub-lbmt-shop`       | `rproxy-edge`  | `172.16.3.0`    | `lbmt-shop`     | `172.16.3.1`    | `/31`  |
| `pri-git-ssh`         | `vpn-edge`     | `10.1.1.0`      | `git-ssh`       | `10.1.1.1`      | `/31`  |
| `pub-git-web`         | `rproxy-edge`  | `172.16.4.0`    | `git-web`       | `172.16.4.1`    | `/31`  |
| `pri-zfs-ssh`         | `vpn-edge`     | `10.1.2.0`      | `zfs-ssh`       | `10.1.2.1`      | `/31`  |
| `pri-zfs-web`         | `vpn-edge`     | `10.1.3.0`      | `zfs-web`       | `10.1.3.1`      | `/31`  |
| `pub-mc-server`       | `rproxy-edge`  | `172.16.5.0`    | `mc-server`     | `172.16.5.1`    | `/31`  |
| `pri-mc-ttyd     `    | `vpn-edge`     | `10.1.4.0`      | `mc-ttyd     `  | `10.1.4.1`      | `/31`  |
| `pub-mc-map`          | `rproxy-edge`  | `172.16.6.0`    | `mc-map`        | `172.16.6.1`    | `/31`  |
| `pri-navid-server`    | `vpn-edge`     | `10.1.5.0`      | `navid-server`  | `10.1.5.1`      | `/31`  |
| `pri-navid-web`       | `vpn-edge`     | `10.1.6.0`      | `navid-web`     | `10.1.6.1`      | `/31`  |
| `navid-server-web`    | `navid-server` | `10.254.1.0`    | `navid-web`     | `10.254.1.1`    | `/31`  |

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
    |  | │ + mc-ttyd             |  | + mc-server             │  | + mc-backup           | |  |
    |  | │                       |  | + mc-map                │  |                       | |  |
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
    |  |                         |  | │ + foto              │ |  |                         |  |
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
                |    host-pri   |     |   host-pub    |   <-- veth pairs between 
                +-------┬-------+     +-------┬-------+       host and michel
                   ┌────┘                     └────┐                     
     +-------------▼-------------+   +-------------▼-------------+
     |     vpn-edge (tun0)       |   |    rproxy-edge (eth0)     |   <-- veth interfaces 
     +-------------┬-------------+   +-------------┬-------------+       in module michel
                   │                               │
     +-------------▼-------------+   +-------------▼-------------+      veth pairs between
     |       pri-container1      |   |       pub-container2      |   <-- michel and other 
     +-------------┬-------------+   +-------------┬-------------+       containers
                   │                               │
       +-----------▼-----------+       +-----------▼-----------+
       |   container 1 (eth0)  |       |   container 2 (eth0)  |   <-- veth interfaces inside 
       +-----------------------+       +-----------------------+       other containers
```
