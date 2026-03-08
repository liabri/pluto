FROM debian:bookworm-slim
LABEL org.opencontainers.image.title="zfs-builder"
LABEL org.opencontainers.image.authors="liabri"

RUN apt-get update && \
	apt-get install -y wget curl ca-certificates git python3 python3-pip r-base fonts-dejavu && \
	rm -rf /var/lib/apts/lists/*

# tinytex
ENV TEXMFVAR=/tmp/.TinyTex-cache/var
ENV TEXMFCONFIG=/tmp/.TinyTex-cache/config
ENV LUAOTFLOAD_DB=/tmp/.TinyTex-cache/.luaotfload-cache.sqlite
ENV TMPDIR=/tmp/.TinyTex-cache/tmp
ENV PATH="/opt/TinyTex/bin/x86_64-linux:$PATH"

RUN R -e "install.packages('tinytex', repos='https://cran.rstudio.com/')" && \
	R -e "tinytex::install_tinytex(dir='/opt/TinyTex')"
RUN mkdir -p /tmp/.TinyTex-cache/var /tmp/.TinyTex-cache/config "$TMPDIR"
RUN tlmgr install scheme-full

# install quarto cli
RUN wget https://github.com/quarto-dev/quarto-cli/releases/download/v1.9.26/quarto-1.9.26-linux-amd64.deb \
	-O /tmp/quarto.deb && \
	apt-get update && apt-get install -y /tmp/quarto.deb && \
	rm -rf /tmp/quarto.deb /var/lib/apt/lists/*

# install watchexec
RUN wget https://github.com/watchexec/watchexec/releases/download/v2.5.0/watchexec-2.5.0-x86_64-unknown-linux-gnu.deb \
	-O /tmp/watchexec.deb && \
	apt-get update && apt-get install -y /tmp/watchexec.deb && \
	rm -rf /tmp/watchexec.deb /var/lib/apt/lists/*


WORKDIR /data
RUN mkdir -p /data/output
RUN chown -R 65533:65533 "/tmp/.TinyTex-cache/" && chown -R 65533:65533 /data/output
RUN echo "project:\n type: website\noutput-dir: output\nexecute:\n cache:true" \
	> /data/_quarto.yml

USER 65533:65533

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["sh", "/entrypoint.sh"]
