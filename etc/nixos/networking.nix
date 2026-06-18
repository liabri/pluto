{ config, pkgs, lib, ... }:

{
  # ----------------------------------------------------------------------------------------
  # host
  # ----------------------------------------------------------------------------------------
  networking.useNetworkd = true;
  systemd.network.enable = true;
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1; # allow host to route WAN traffic to Caddy & WG
  systemd.network.wait-online.anyInterface = true; # prevent deadlocks

    systemd.network.networks = {
        "20-veth-rproxy-host" = {
            matchConfig.Name = "veth-rproxy";
            address = [ "192.168.50.0/31" ];
            networkConfig.IPv4Forwarding = "yes";
            linkConfig.ActivationPolicy = "always-up";
        };

        "25-veth-vpn-host" = {
            matchConfig.Name = "veth-vpn";
            address = [ "192.168.101.0/31" ];
            networkConfig.IPv4Forwarding = "yes";
            linkConfig.ActivationPolicy = "always-up";
        };
    };

  # ----------------------------------------------------------------------------------------
  # host security (nftables)
  # ----------------------------------------------------------------------------------------
  networking.nftables = {
    enable = true;
    ruleset = ''
      flush ruleset

      table inet filter {
          chain input {
              type filter hook input priority 0; policy drop;
              iifname "lo" accept
              ct state established,related accept
              ct state invalid drop
          }

          chain forward {
              type filter hook forward priority 0; policy drop;
              ct state established,related accept
              ct state invalid drop

              # Route incoming WAN traffic through to Caddy's entry points
              ip daddr 192.168.50.1 tcp dport { 80, 443, 25565 } accept

              # Route incoming WAN traffic through to VPN's entry point
              ip daddr 192.168.101.1 udp dport 51820 accept

              # Allow traffic from Caddy's link to exit out onto the physical internet
              iifname "veth-rproxy" accept

              # Allow traffic from VPN's link to exit out onto the physical internet
              iifname "veth-vpn" accept
          }
      }

      table ip nat {
          chain prerouting {
              type nat hook prerouting priority dstnat;
              # Transparently forward incoming public traffic straight to Caddy's internal IP
              tcp dport { 80, 443, 25565 } dnat to 192.168.50.1

              # Transparently forward incoming WireGuard traffic straight to vpn-edge
              udp dport 51820 dnat to 192.168.101.1
          }

          chain postrouting {
              type nat hook postrouting priority srcnat;
              # Masquerade outbound traffic leaving the server's main link (eth0)
              oifname "eth0" masquerade
          }
      }
    '';
  };
}
