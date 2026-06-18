{ config, pkgs, ... }:

{
    systemd.services."container@lbmt-darkroom" = {
        after = [ "container@rproxy-edge.service" ];
        requires = [ "container@rproxy-edge.service" ];
      };
  # ----------------------------------------------------------------------------------------
  # container 3: lbmt-darkroom (Static Web Server)
  # ----------------------------------------------------------------------------------------
  containers."lbmt-darkroom" = {
    autoStart = true;
    ephemeral = true;
    privateNetwork = true;

    interfaces = [ "dkrm-eth0" ];

    bindMounts = {
      "/var/www/html" = {
        hostPath = "/srv/lbmt-darkroom";
        isReadOnly = true;
      };
    };

    config = { config, pkgs, ... }: {
      system.stateVersion = "26.05";

      networking.interfaces."dkrm-eth0".ipv4.addresses = [{
        address = "172.16.1.1";
        prefixLength = 31;
      }];
      networking.defaultGateway = "172.16.1.0";

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 8080 ];
      };

      services.static-web-server = {
        enable = true;
        listen = "0.0.0.0:8080";
        root = "/var/www/html";

        configuration = {
          general = {
            security-headers = true;
            directory-listing = false;
          };
        };
      };

      systemd.services.static-web-server.serviceConfig = {
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" ];
      };
    };
  };
}
