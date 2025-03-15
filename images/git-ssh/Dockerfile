FROM alpine:3.21.3

ARG GIT_VERSION=2.47.2-r0
ARG OPENSSH_VERSION=9.9_p2-r0

RUN set -ex; \
    apk add --no-cache \
    git${GIT_VERSION:+=}${GIT_VERSION} \
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
COPY resources/etc/ssh/sshd_config /etc/ssh/sshd_config

# change welcome message
COPY resources/etc/motd /etc/motd

RUN mkdir ${GIT_HOME}/git-shell-commands
RUN mkdir /home/git/.ssh
RUN chown -R git:git ${GIT_HOME}/.ssh
RUN chmod 700 ${GIT_HOME}/.ssh
#RUN chmod -R 600 ${GIT_HOME}/.ssh/*

#RUN chown -R git:git /srv/git/
#RUN chown -R ug+rwX /srv/git/

EXPOSE 22

ENTRYPOINT ["/usr/sbin/sshd"]
CMD ["-D"]

 

	
