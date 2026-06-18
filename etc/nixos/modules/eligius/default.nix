# ==========================================================================================
# PLUTO APP: ELIGIUS GIT HOSTING (DECLARATIVE & ULTRA-MINIMALIST)
# ==========================================================================================

{ config, pkgs, lib, ... }:

let
    identities = import ../identities.nix;
    gitZfsPath = "/mahzen/git";

  # ----------------------------------------------------------------------------------------
  # ASSET MERGER: Combines default CGit assets with your custom htdocs folder
  # ----------------------------------------------------------------------------------------
  cgitAssets = pkgs.runCommand "cgit-custom-assets" {} ''
    mkdir -p $out
    cp -r ${pkgs.cgit}/cgit/* $out/
    if [ -d ${./htdocs} ]; then
      cp -f ${./htdocs}/* $out/ 2>/dev/null || true
    fi
  '';

    # ----------------------------------------------------------------------------------------
    # ABOUT FILTER WRAPPER
    # ----------------------------------------------------------------------------------------
    cgitAboutFilter = pkgs.writeShellScript "cgit-about-filter" ''
          # CGit natively sets the CGIT_REPO_PATH environment variable for filters.
          # We use it to quietly grab the all-time commit count directly from the Git DAG.
          COMMIT_COUNT=$(${pkgs.git}/bin/git -C "$CGIT_REPO_PATH" rev-list --count HEAD 2>/dev/null || echo "0")

          # 1. Echo a little HTML badge (safe to do because we use --unsafe in cmark)
          # 2. Append an empty line
          # 3. Use `cat -` to pull in the original README.md from standard input
          # 4. Pipe the whole thing directly into the Markdown parser
          (
            echo "<div style='font-size: 0.9em; opacity: 0.7; margin-bottom: 15px;'><strong>🚀 Total Commits:</strong> $COMMIT_COUNT</div>"
            echo ""
            cat -
          ) | exec ${pkgs.cmark-gfm}/bin/cmark-gfm \
            --extension table \
            --extension strikethrough \
            --extension autolink \
            --extension tasklist \
            --unsafe
        '';

  # ----------------------------------------------------------------------------------------
  # custom http server
  # ----------------------------------------------------------------------------------------
  cgitBridge = pkgs.runCommand "cgit-bridge" { buildInputs = [ pkgs.go ]; } ''
    mkdir -p $out/bin
    export GOCACHE=$TMPDIR/go-cache
    export GOPATH=$TMPDIR/go
    export GO111MODULE=off

    cat << EOF > main.go
    package main
    import ("net/http"; "net/http/cgi"; "os"; "log"; "path"; "strings")
    func main() {
        http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
            static := "${cgitAssets}/" + path.Base(r.URL.Path)
            if s, err := os.Stat(static); err == nil && !s.IsDir() { http.ServeFile(w, r, static); return }

            // if not a static file, serve the cgit.cgi
            repoPath := strings.TrimPrefix(r.URL.Path, "/git")

            // SMART HTTP PROTOCOL (For 'git clone' and 'git pull')
            if strings.HasSuffix(r.URL.Path, "/info/refs") || strings.HasSuffix(r.URL.Path, "/git-upload-pack") {
                gitHandler := &cgi.Handler{
                    Path: "${pkgs.git}/libexec/git-core/git-http-backend",
                    Env: []string{
                        "GIT_PROJECT_ROOT=/srv/git",
                        "GIT_HTTP_EXPORT_ALL=1",
                        "PATH_INFO=" + repoPath,
                        "GIT_CONFIG_SYSTEM=/etc/gitconfig",
                        "PATH=${lib.makeBinPath [ pkgs.git pkgs.coreutils ]}",
                    },
                }
                gitHandler.ServeHTTP(w, r)
                return
            }

            // REGULAR CGIT WEB UI
            cgit := &cgi.Handler{
                Path: "${pkgs.cgit}/cgit/cgit.cgi",
                Env: []string{
                    "SCRIPT_NAME=/git",
                    "PATH_INFO=" + repoPath,
                    "QUERY_STRING=" + r.URL.RawQuery,
                    "CGIT_CONFIG=/etc/cgitrc",
                    "GIT_CONFIG_SYSTEM=/etc/gitconfig",
                    "PYTHONDONTWRITEBYTECODE=1",
                    "PATH=${lib.makeBinPath [ pkgs.python3 pkgs.python3Packages.pygments pkgs.coreutils ]}",
                },
            }
            cgit.ServeHTTP(w, r)
        })
        log.Fatal(http.ListenAndServe(":8080", nil))
    }
    EOF

    # Compile a 100% static, zero-dependency binary
    CGO_ENABLED=0 go build -ldflags="-s -w" -o $out/bin/cgit-bridge main.go
  '';

in {

    systemd.services."container@git-web" = {
        after = [ "container@rproxy-edge.service" ];
        requires = [ "container@rproxy-edge.service" ];
    };

    systemd.services."container@git-ssh" = {
        after = [ "container@vpn-edge.service" ];
        requires = [ "container@vpn-edge.service" ];
    };

  # ----------------------------------------------------------------------------------------
  # container 1: git-ssh (private access)
  # ----------------------------------------------------------------------------------------
  containers."git-ssh" = {
    autoStart = true;
    ephemeral = true;
    privateNetwork = true;
    interfaces = [ "git-ssh-eth0" ];

    bindMounts = {
      "/srv/git" = { hostPath = gitZfsPath; isReadOnly = false; };
      "/srv/lbmt-darkroom" = { hostPath = "/srv/lbmt-darkroom"; isReadOnly = false; };
      # "/srv/akitio-server" = { hostPath = "/srv/akitio-server"; isReadOnly = false; };
    };

    config = { config, pkgs, ... }: {
      system.stateVersion = "25.11";
      networking.interfaces."git-ssh-eth0".ipv4.addresses = [{ address = "10.1.1.1"; prefixLength = 31; }];
      networking.defaultGateway = "10.1.1.0";

      environment.etc."git-hooks/post-receive" = {
            mode = "0755";
            text = ''
              #!/bin/sh
              export PATH=/run/current-system/sw/bin:$PATH
              SERVICE_NAME=$(basename "$(pwd)" .git)

              # GITHUB MIRROR
              # echo "[Eligius] Pushing mirror to GitHub..."
              # git push --mirror "git@github.com:liabri/$SERVICE_NAME.git" || echo "[Eligius] ⚠️ Mirror push failed. Does the repo exist on GitHub?"

              # LIVE SERVICE DEPLOYMENT
              # If the folder exists on the SSD, unpack it. If it doesn't, do absolutely nothing.
              if [ -d "/srv/$SERVICE_NAME" ]; then
              echo "[Eligius] Live service directory found. Deploying to /srv/$SERVICE_NAME..."
              GIT_WORK_TREE=/srv/$SERVICE_NAME git checkout -f master
              fi
          '';
      };

      # each repo has this git hook, but it only works if there is a matching folder at /srv/
      environment.etc."gitconfig".text = ''
      [core]
          hooksPath = /etc/git-hooks
      '';

      environment.systemPackages = with pkgs; [ git git-lfs git-lfs-transfer ];

      users.groups.git = {};
      users.users.git = {
        isNormalUser = true;
        group = "git";
        createHome = false;
        home = "/srv/git";
        shell = "${pkgs.git}/bin/git-shell";
        openssh.authorizedKeys.keys = identities.gitUsers;
      };

      environment.etc."motd".text = ''
        Welcome to liabri's ssh git server -- where you can't do a thing
      '';

      system.activationScripts.git-shell-commands.text = ''
        mkdir -p /srv/git/git-shell-commands

        if [ -d ${./git-shell-commands} ]; then
            cp -f ${./git-shell-commands}/* /srv/git/git-shell-commands/ 2>/dev/null || true
            chmod +x /srv/git/git-shell-commands/* 2>/dev/null || true
        fi

        # Link the LFS transfer tool natively found in Nixpkgs
        ln -sf ${pkgs.git-lfs-transfer}/bin/git-lfs-transfer /srv/git/git-shell-commands/git-lfs-transfer
        chown -R git:git /srv/git/git-shell-commands
      '';

      # OUTBOUND SSH CONFIGURATION (CLIENT)
        programs.ssh = {
            knownHosts."github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
            extraConfig = ''
            Host github.com
                IdentityFile /srv/git/.ssh/eligius-mirror
                IdentitiesOnly yes
            '';
        };

     # INBOUND SSH CONFIGURATION (SERVER)
     services.openssh = {
        enable = true;
        settings = {
            PasswordAuthentication = false;
            PermitEmptyPasswords = false;
            PermitRootLogin = "no";
            AllowTcpForwarding = false;
            X11Forwarding = false;
            LogLevel = "DEBUG3";
        };
        extraConfig = ''
            GatewayPorts no
            KbdInteractiveAuthentication no
            PrintMotd yes
        '';
      };
    };
  };

  # ----------------------------------------------------------------------------------------
  # container 2: git-web (public cgit via custom go bridge)
  # ----------------------------------------------------------------------------------------
  containers."git-web" = {
    autoStart = true;
    ephemeral = true;
    privateNetwork = true;
    interfaces = [ "git-web-eth0" ];

    bindMounts = {
      "/srv/git" = { hostPath = gitZfsPath; isReadOnly = true; };
    };

    config = { config, pkgs, ... }: {
      system.stateVersion = "25.11";
      networking.firewall.allowedTCPPorts = [ 8080 ];
      networking.interfaces."git-web-eth0".ipv4.addresses = [{ address = "172.16.4.1"; prefixLength = 31; }];
      networking.defaultGateway = "172.16.4.0";

      environment.etc."gitconfig".text = ''
            [safe]
                directory = *
        '';

      environment.etc."cgitrc".text = ''
        virtual-root=/git
        css=/git/cgit.css
        logo=/git/cgit.svg
        favicon=/git/favicon.ico
        js=/git/cgit_custom.js

        robots=noindex, nofollow

        remove-suffix=1
        repository-sort=age
        enable-git-config=1
        scan-hidden-path=0
        clone-url=http://192.168.10.149/git/$CGIT_REPO_URL

        about-filter=${cgitAboutFilter}
        source-filter=${pkgs.cgit}/lib/cgit/filters/syntax-highlighting.py
        readme=:README.md
        default-context=about

        enable-commit-graph=1
        enable-http-clone=0
        enable-index-links=1
        enable-subject-links=1
        enable-log-linecount=1
        enable-log-filecount=1
        max-stats=year

        cache-size=1024
        max-commit-count=50
        summary-log=10

        mimetype.gif=image/gif
        mimetype.html=text/html
        mimetype.jpg=image/jpeg
        mimetype.jpeg=image/jpeg
        mimetype.pdf=application/pdf
        mimetype.png=image/png
        mimetype.svg=image/svg+xml

        root-desc=all my projects from 2017 until the present centralised in one place.
        root-title=liabri's git directory

        scan-path=/srv/git
      '';

      systemd.services.cgit-go-bridge = {
        description = "Custom Minimal Go CGI Bridge for CGit";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          ExecStart = "${cgitBridge}/bin/cgit-bridge";
          Restart = "always";
          TasksMax = 1024;

          User = "nobody";
          Group = "nogroup";
          NoNewPrivileges = true;

          ProtectSystem = "strict";
          CacheDirectory = "cgit";
          ProtectHome = true;
          PrivateTmp = true;
          ProtectControlGroups = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          RestrictNamespaces = true;
          CapabilityBoundingSet = "";
          PrivateDevices = true;
          RestrictAddressFamilies = [ "AF_INET" ];
        };
      };
    };
  };
}
