FROM alpine:3.21.3

LABEL org.opencontainers.image.title="git-ssh"
LABEL org.opencontainers.image.description="provides an ssh server with a git user"
LABEL org.opencontainers.image.authors="liabri"

ARG GIT_VERSION=2.47.2-r0
ARG GIT_LFS_VERSION=3.6.0-r3
ARG OPENSSH_VERSION=9.9_p2-r0

RUN set -ex; \
    apk add --no-cache \
    git${GIT_VERSION:+=}${GIT_VERSION} \
    git-lfs${GIT_LFS_VERSION:+=}${GIT_LFS_VERSION} \
    openssh${OPENSSH_VERSION:+=}${OPENSSH_VERSION}

# generate ssh host keys
RUN ssh-keygen -A

ENV GIT_USER=git
ENV GIT_GROUP=git
ENV GIT_HOME = /home/${GIT_USER}

# create git user 
RUN set -eux; \
    addgroup "${GIT_GROUP}"; \
    adduser \
        --gecos "git user" \
        --ingroup "${GIT_GROUP}" \
        --disabled-password \
        --shell "$(which git-shell)" \
        "${GIT_USER}"; \
     echo "${GIT_USER}:12345" | chpasswd
RUN passwd -d ${GIT_USER}

# sshd_config to enable access key and disable access password
COPY sshd_config /etc/ssh/sshd_config

# change welcome message
COPY motd /etc/motd

# scripts accessible through ssh login 
COPY git-shell-commands/ /home/git/git-shell-commands/

# lfs over ssh support
RUN apk add --no-cache go
RUN go install github.com/charmbracelet/git-lfs-transfer@latest
RUN ln -s /root/go/bin/git-lfs-transfer /home/git/git-shell-commands/git-lfs-transfer

# .ssh folder perms
RUN mkdir ${GIT_HOME}/.ssh \
    && chown -R git:git ${GIT_HOME}/.ssh \ 
    && chmod 700 ${GIT_HOME}/.ssh

EXPOSE 22

ENTRYPOINT ["/usr/sbin/sshd"]
CMD ["-D"]
