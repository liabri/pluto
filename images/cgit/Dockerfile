FROM alpine:latest AS builder

RUN apk add --no-cache \
	build-base zlib-dev zlib-static pcre-dev \
	openssl-dev openssl-libs-static curl tar go git

WORKDIR /build

# build static cgit
RUN git clone https://git.zx2c4.com/cgit
WORKDIR /build/cgit
RUN GIT_VER=$(grep "^GIT_VER" Makefile | cut -d'=' -f2 | xargs) && \
	git clone --depth 1 --branch v${GIT_VER} https://github.com/git/git.git git
RUN make -j$(nproc) LDFLAGS="-static" NO_GETTEXT=1 NO_LUA=1 NO_PYTHON=1 NO_OPENSSL=1 NO_REGEX=1 BLK_SHA1=1 

# build static md4c markdown rendered 
WORKDIR /build/md4c
RUN curl -L https://github.com/mity/md4c/archive/refs/tags/release-0.5.2.tar.gz | tar xz --strip-components=1 && \
	gcc -static -O3 \
	-DMD_VERSION_MAJOR=0 -DMD_VERSION_MINOR=5 -DMD_VERSION_RELEASE=2 \
	src/md4c.c src/md4c-html.c src/entity.c md2html/md2html.c md2html/cmdline.c \
	-Isrc -o md-renderer


# build static go cgi-bridge
WORKDIR /app
RUN cat <<EOF > main.go
package main
import ("net/http"; "net/http/cgi"; "os"; "log"; "path"; "strings")
func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		static := "/var/www/htdocs/" + path.Base(r.URL.Path)
		if s, err := os.Stat(static); err == nil && !s.IsDir() { http.ServeFile(w, r, static); return }

		// if not a static file, serve the cgit.cgi
		repoPath := strings.TrimPrefix(r.URL.Path, "/git")
		cgit := &cgi.Handler{Path: "/usr/bin/cgit.cgi", Env: []string{"SCRIPT_NAME=/git", "PATH_INFO="+repoPath, "QUERY_STRING="+r.URL.RawQuery}}
		cgit.ServeHTTP(w, r)
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
EOF
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o bridge main.go


# uid -> name in /etc/passwd
RUN mkdir -p /rootfs/etc
RUN echo "git:x:4001:4000:git user:/home/git:/sbin/nologin" > /rootfs/etc/passwd
RUN echo "git:x:4000:git" > /rootfs/etc/group


# assembly of rootfs
RUN mkdir -p /rootfs/usr/bin /rootfs/etc/ /rootfs/var/www/htdocs/ /rootfs/tmp /rootfs/var/cache/cgit
RUN chown -R 4001:4000 /rootfs/var/www/htdocs /rootfs/tmp /rootfs/var/cache/cgit
RUN cp /build/cgit/cgit /rootfs/usr/bin/cgit.cgi && \
	cp /build/cgit/cgit.js /rootfs/var/www/htdocs/cgit.js && \
	cp /app/bridge /rootfs/usr/bin/bridge && \
	cp /build/md4c/md-renderer /rootfs/usr/bin/md-renderer && \
	strip /rootfs/usr/bin/*

FROM scratch

LABEL org.opencontainers.image.title="cgit"
LABEL org.opencontainers.image.description="provides a cgit instance to run behind a reverse proxy"
LABEL org.opencontainers.image.authors="liabri"

COPY --from=builder /rootfs /
COPY cgitrc /etc/cgitrc
COPY --chown=4001:4000 htdocs/cgit.css /var/www/htdocs/cgit.css
COPY --chown=4001:4000 htdocs/cgit.svg /var/www/htdocs/cgit.svg
COPY htdocs/favicon.ico /var/www/htdocs/favicon.ico
COPY --chown=4001:4000 htdocs/robots.txt /var/www/htdocs/robots.txt

USER 4001:4000
ENTRYPOINT ["/usr/bin/bridge"]
