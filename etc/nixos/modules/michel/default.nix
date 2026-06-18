{ config, pkgs, lib, ... }:

let

    identities = import ../identities.nix;
  # ----------------------------------------------------------------------------------------
  # builder
  # ----------------------------------------------------------------------------------------
    customCaddy = pkgs.caddy.withPlugins {
        plugins = [ "github.com/mholt/caddy-l4@v0.1.2-0.20260603064814-1d459d3c0a32" ];
        hash = "sha256-7WTeuUccm6EpxJswz9tIVsakPwaI/MKFtOXje0YnnMg=";
    };

in {
  # ----------------------------------------------------------------------------------------
  # container 1: caddy reverse proxy (public)
  # ----------------------------------------------------------------------------------------
  containers."rproxy-edge" = {
    autoStart = true;
    ephemeral = true;
    privateNetwork = true;

    extraFlags = [
        "--network-veth-extra=veth-rproxy:host-pub"
        "--network-veth-extra=git-web-eth0:pub-git-web"
        "--network-veth-extra=dkrm-eth0:pub-lbmt-foto"
        "--network-veth-extra=mc-eth0:pub-mc-server"
    ];

    bindMounts = {
        "/srv/stats" = { hostPath = "/srv/stats"; isReadOnly = true; };
    };

    config = { config, pkgs, ... }: {
      system.stateVersion = "25.11";

      networking.defaultGateway = "192.168.50.0"; # outbound traffic routes back via host veth-rproxy
      networking.nameservers = [ "9.9.9.9" "1.1.1.1" ];
      networking.firewall.allowedTCPPorts = [ 80 443 25565 ];
      networking.interfaces = {
        "host-pub".ipv4.addresses = [{ address = "192.168.50.1"; prefixLength = 31; }];
        "pub-lbmt-foto".ipv4.addresses = [{ address = "172.16.1.0"; prefixLength = 31; }];
        "pub-mc-server".ipv4.addresses = [{ address = "172.16.5.0"; prefixLength = 31; }];
        "pub-git-web".ipv4.addresses = [{ address = "172.16.4.0"; prefixLength = 31; }];
      };

            services.caddy = {
                enable = true;
                package = customCaddy;
                configFile = ./Caddyfile;
            };
      # ... rest of your custom Caddy sandboxing logic
        };
    };

    # ----------------------------------------------------------------------------------------
      # GOACCESS AUTO-GENERATOR
      # ----------------------------------------------------------------------------------------
        systemd.services.generate-web-stats = {
            description = "Compile Segregated GoAccess Analytics Dashboards";
            path = with pkgs; [ systemd gnugrep goaccess coreutils ];
            script = ''
                mkdir -p /srv/stats

                # dump the live access log stream into a variable to avoid hammering journalctl 5 times
                LOG_DATA=$(journalctl -M rproxy-edge -u caddy -o cat | grep '"logger":"http.log.access' || true)

                if [ -n "$LOG_DATA" ]; then
                    # git-web
                    echo "$LOG_DATA" | grep '"uri":"/git' | goaccess - --log-format=CADDY -o /srv/stats/git-web.html || true

                    # lbmt-darkroom
                    echo "$LOG_DATA" | grep '"uri":"/","' | goaccess - --log-format=CADDY -o /srv/stats/lbmt-darkroom.html || true
                fi

                chmod 644 /srv/stats/*.html 2>/dev/null || true
            '';
        };

      systemd.timers.generate-web-stats = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/30"; # re-compile every 30 minutes
          Persistent = true;
        };
      };


  # ----------------------------------------------------------------------------------------
    # container 2: vpn-edge (WireGuard Gateway)
    # ----------------------------------------------------------------------------------------
    containers."vpn-edge" = {
      autoStart = true;
      ephemeral = true;
      privateNetwork = true;

      extraFlags = [
          "--network-veth-extra=veth-vpn:host-pri"
          "--network-veth-extra=git-ssh-eth0:pri-git-ssh"
          "--network-veth-extra=ling-ai-eth0:pri-ling-ai"
      ];

      bindMounts = {
          "/etc/wireguard" = { hostPath = "/var/lib/wireguard"; isReadOnly = true; };
      };

      config = { config, pkgs, ... }: {
        system.stateVersion = "25.11";

        networking.defaultGateway = "192.168.101.0";
        networking.nameservers = [ "9.9.9.9" "1.1.1.1" ];
        networking.firewall.allowedUDPPorts = [ 51820 ];
        networking.interfaces = {
          "host-pri".ipv4.addresses = [{ address = "192.168.101.1"; prefixLength = 31; }];
          "pri-git-ssh".ipv4.addresses = [{ address = "10.1.1.0"; prefixLength = 31; }];
          "pri-ling-ai".ipv4.addresses = [{ address = "10.1.7.0"; prefixLength = 31; }];
          # "pri-mc-ttyd".ipv4.addresses = [{ address = "10.1.4.0"; prefixLength = 31; }];
        };

        # declarative WireGuard Setup
        networking.wireguard.interfaces = {
          wg0 = {
            ips = [ "10.100.0.1/24" ]; # The internal VPN client subnet
            listenPort = 51820;

            # path to the private key on the host (mapped via bindMounts later, or sops-nix)
            privateKeyFile = "/etc/wireguard/private.key";

            # postUp routing: NAT the VPN clients so the backend containers just see the vpn-edge IP
            postSetup = ''
              ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -j MASQUERADE
            '';
            postShutdown = ''
              ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -j MASQUERADE
            '';

            peers = [
              {
                # venus-pluto
                publicKey = identities.vpnPeers.venus;
                allowedIPs = [ "10.100.0.2/32" ];
              }
            ];
          };
        };
      };
    };
}
