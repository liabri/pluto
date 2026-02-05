# pluto
my personal homelab completely based on alpine and podman. all images are created by me.

## modules

containers are organised into functional modules based on responsibility and purpose. podman pods were considered for grouping, however, they were avoided to **minimise attack surface** and allow **fine-grained per-container network and privilege isolation**. pods enforce shared namespaces (network, IPC, and optionally PID) across all member containers, which is often not necessary.

this approach keeps containers **semantically grouped** while preserving **runtime isolation**, **flexible networking**, and **selective cooperation**, rather than imposing rigid coupling through pods.

### michel
the `michel` module acts as the semantic gateway for all external access. external traffic is intended to conceptually flow through michel into the `privat` and `public` networks, where a wireguard VPN and an HTTP/TCP reverse-proxy handle routing, respectively. one day, move reverse-proxy-edge to an external server to mask my homelab. **containers**: `reverse-proxy-edge`; `reverse-proxy-stats` (go access); `vpn-edge`.

### frangisk
my personal website: photography gallery, weblog, and shop;
**containers**: `lbmt-darkroom`; `lbmt-weblog`; `lbmt-shop`.

### eligius
the `eligius` module provides `privat` ssh-access git hosting for a repository pool, with a `public` read-only interface via `cgit`. **containers**: `git-ssh`; `git-web`.

### isidore
a standard `openssh` server runs in container `nas-sftp` which **bind-mounts** the nas (in my case that is /zfs/storage). the expectation is to be able to mount the drive on devices via `sshfs` or use clients like `filestash` on the web. `sshfs` is rather slow due to its encryption and other factors, so I employ the **golden data** paradigm. this paradigms considers the device a satellite which utilises `nas-sftp` and `rsync` for a git-like workflow. this implies pulling data, pushing local edits, and never directly editing the nas via `sshfs`, except for creating or deleting files and folders.

i am still considering add a  `nas-nfs-ganesha` container to mount the storage on my PC. because, as is, both my PC and laptop are satellites of my server. this leads to have potentially having 3 copies of the same data. if this data is volatile (i.e. edited a lot), it can get messy to track which is the most up to date. if i mount the nas via `nfs` on my PC, the laptop becomes a satellite of my PC. this reduces the possible number of copies to 2.

**containers**: `nas-sftp`; `nas-explorer-web`.

### akitio
**containers**: `minecraft-server`; `minecraft-ttyd-rcon`; `minecraft-map`; `minecraft-backup`.

### cecilia
**containers**: `navidrome-server`; `navidrome-web-client`.

### gavrilo
prospective name for cctv server

### genesius
prospective name for radarr etccc, but im unsure.

## images

### localhost/lighttpd: a generic lighttpd server
use launch parameters: `-D -f /etc/lighttpd/lighttpd.conf"`. the server serves whatever is at `/var/www/html`, and requires /var/lighttpd.conf to be defined as follows:
```
server.tag="this-is-a-tag"
server.port=8080
```

### localhost/git-ssh: a simple ssh server 
limited to git-shell-commands `ls` `mk <repo>` and `rm <repo>`.
the default directory is /home/git/repos (as defined in git-shell-commands), I would suggest mounting your repo directory here. Additionally, following the ssh standard, `/home/git/.ssh/authorized_keys` will be read. supports git-lfs! requires X package on client.

### localhost/cgit: a modified lighttpd image serving cgit
all definitions must be done as the lighttpd image, with the addition of a cgitrc which must be mounted to `/etc/cgitrc`

### localhost/caddy-reverse-proxy
a `Caddyfile` must be mounted to `etc/caddy/Caddyfile/`. logging is enabled via 
```    log {
        output file /var/log/caddy/access.log
        format json
    }
```

### localhost/minecraft-server
simply provides a Java OpenJdk 21 environment exposing port 25565. working-tree is found in a named volume mount for persistence. before every launch, `check-working-tree.sh` confirms it is up to date with the origin, and if not, will update. the world will also be in this named volume mount, and therefore this image ideally should not ever be mounted with a host bind mount, for security purposes. my system uses borg in another container which mounts the named volume containing the server+world, and backups the world to my `/zfs/storage`.

## todo
- static site gen for blog need to add --prefix option for all links (in this case /blog/);
- git check if a git user (instead of liam) would be good for eligius. (i dont think so as podman is running under liam);
- cgit private directory?;
- cgit hide index.cgit from url (rewrite instead of redirect but not working?);
- cgit regarding above (currently) redirect, i am regex matching for paths NOT containing " . ", which fucks up for files like fabric.json;
- cgit fix about-formatting, its 404ing (its detecting the README tho);
- cgit fix http cloning, currently trying http://x.x.x.x/git/dots (which redirects to /git/index.cgi/dots, idk if it should?);
- cgit releases (binaries) (might need to code extension myself);
- cgit some tabs are broken for large repos;
- git-ssh NOTE git-lfs-transfer will be required on the client to use lfs-over-ssh;
- reverse-proxy statistics

## cheatsheet

- list containers - `podman ps`
- start pod - `doas rc-service pod-{name} start`
- view user-space network interfaces (netavark) - `doas nsenter -t $(pgrep -u $USER podman) -n ip link`

## to look into/notes
- users/owners
- when mounting, prioritise read-only volumes. use named volumes instead of host bind mounts if persistence is needed.
- reduce root privileges such as CAP_SYS_ADMIN; CAP_NET_ADMIN; CAP_SYS_MODULE. (list enabled privileges: `podman run --rm alpine capsh --print | grep Bounding`);
- `cat /sys/kernel/security/apparmor/profiles` apparmor enabled if returns anything; `podman run --rm alpine grep Seccomp /proc/self/status` "Seccomp: 2" means a filter is active (the default one). real test: `podman run --rm alpine reboot`. logs: `dmesg | grep -iE "audit|apparmor|seccomp"`

## networking
this network architecture utilises a dual-hub, zero-trust model to enforce strict lateral isolation between containers, which unless is required, is usually done via `socat` or opening a `veth` between the appropriate containers. additionally, standard container bridge networking is bypassed in favour of manual `veth` pair injection directly into container network namespaces, which eliminate the host-level gateway and the associated risk of inter-container leaks, common in flat network. containers are segmented into two distinct "hub", a `privat` hub (via `vpn-edge`), and a `public` hub (via `reverse-proxy-edge`). this is where communication is restricted to point-to-point virtual links using `/30` subnets.

the Alpine host functions as a silent switchboard; because interfaces are moved into namespaces, the host routing table remains pristine and unexploitable. this is also paired with granular traffic control, as each connection is a dedicated "virtual wire," precise `nftables` filtering is done at the hub level rather than relying on broad, automated firewall rules.

| island | link name | hub end (IP) | spoke end (IP) | subnet | purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **privat** | `veth-priv-git` | `10.0.1.1` | `10.0.1.2` | `10.0.1.0/30` | internal Git access via WireGuard |
| **privat** | `veth-priv-nas` | `10.0.1.5` | `10.0.1.6` | `10.0.1.4/30` | internal NAS access via WireGuard |
| **public** | `veth-pub-web`| `10.0.2.1` | `10.0.2.2` | `10.0.2.0/30` | inbound HTTP/HTTPS traffic |
| **public** | `veth-pub-mc` | `10.0.2.5` | `10.0.2.6` | `10.0.2.4/30` | minecraft TCP stream (Port 25565) |

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
         |  (network `privat`)   |     |   (network `public`)  |
         +-----------┬-----------+     +-----------┬-----------+
                     └┐                           ┌┘
       +--------------┼---------------------------┼--------------+
       |              │       module michel       │              |
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
                    ┌─┘                          ┌┘
    +---------------┼----------------------------┼--------------------------------------------+
    |               │     network islands        │                                            |
    |  +------------▼------------+  +------------▼------------+  +-------------------------+  |
    |  | private island          |  | public island           |  | networkless containers  |  |
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
    |  |                         |  | │ + photography       │ |  |                         |  |
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
                         |     Host eth0     |   <-- Physical network interface (LAN/WAN)
                         +---------┬---------+
                        ┌──────────┴──────────┐                     
                +-------▼-------+ OR  +-------▼-------+
                |   veth-priv   |     |   veth-pub    |   <-- veth pairs (host side)
                +-------┬-------+     +-------┬-------+
                     ┌──┘                     └──┐                     
         +-----------▼-----------+   +-----------▼-----------+
         |    wireguard (tun0)   |   | http-rev-proxy (eth0) |   <-- module michel
         +-----------┬-----------+   +-----------┬-----------+
                     │                           │
             +-------▼-------+           +-------▼-------+
             | veth-vpn-con1 |           | veth-vpn-con2 |  
             +-------┬-------+           +-------┬-------+
                     │                           │
         +-----------▼-----------+   +-----------▼-----------+
         |   container 1 (eth0)  |   |   container 2 (eth0)  |   <-- Container interfaces
         +-----------------------+   +-----------------------+
```

## security
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
