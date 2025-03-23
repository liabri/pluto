# pluto
my personal homelab completely based on alpine and podman. all images are created by me. 

## pods

pods are semantically distinguished:

michel - protection: http-reverse-proxy 
frangisk - serving publicly:  
eligius - git: git-ssh; cgit
isidore - nas: nas-ganesha on zfs
gavrilo - cctv
akitio - minecraft
genesius - radarr etc..
cecilia - music

### containers

michel-http-reverse-proxy: a simple reverse proxy in caddy;
frangisk-photography: my photography portfolio;
frangisk-weblog: my blog;
eligius-git-ssh: a simple ssh server to interact with git;
eligius-cgit: a simple frontend to view my repo director;

## todo
separate network namespaces for containers (currently per-pod, make per-container)
static site gen for blog need to add --prefix option for all links 

akitio-server
akitio-backup (borg vs zfs? unfortunately i dont think git-lfs would work, but id prefer it to stay with the same "versioning")
akitio-little-a-map
akitio attach to console (stdin & tty), then decide whether to ssh into it or use an online term hosted akitio-webterm to interact. ssh more minimal, i doubt i need to access akitio from a webterm often. 

cgit private directory?
cgit hide index.cgit from url (rewrite instead of redirect but not working?) 
cgit fix about-formatting, its 404ing (its detecting the README tho)
cgit fix http cloning, currently trying http://x.x.x.x/git/dots (which redirects to /git/index.cgi/dots, idk if it should?)
cgit releases (binaries)
git-ssh NOTE git-lfs-transfer will be required on the client to use lfs-over-ssh
