# ==========================================================================================
# PLUTO APP: AKITIO MINECRAFT SERVER (DECLARATIVE)
# ==========================================================================================

{ config, pkgs, lib, sources, ... }:

let
  rconPassword = "testingbaby"; # TODO: move to sops-nix
  workingTreeDir = "/var/lib/minecraft/akitio-working-tree";

  # ZFS Paths
  worldZfsPath = "/mahzen/loghob/minecraft/akitio/world";
  worldDataset = "mahzen/loghob/minecraft/akitio/world"; # remove this ?

  # dynamically pulls the built server files from your Git
  serverPackage = sources.akitio-src.packages."x86_64-linux".default;

in {

  # ----------------------------------------------------------------------------------------
  # host preparation (declarative permissions)
  # ----------------------------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    "d /var/lib/minecraft 0755 root root -"
    "Z ${workingTreeDir} 2755 65534 65534 -"
  ];

  # ----------------------------------------------------------------------------------------
  # container 1: minecraft server runtime (public access)
  # ----------------------------------------------------------------------------------------
  containers."mc-server" = {
    autoStart = true;
    ephemeral = true;
    privateNetwork = true;
    interfaces = [ "mc-eth0" "rcon-mc" ];

    bindMounts = {
      "/srv/minecraft" = { hostPath = workingTreeDir; isReadOnly = false; };
    };

    config = { config, pkgs, ... }: {
      system.stateVersion = "25.11";
      networking.interfaces."mc-eth0".ipv4.addresses = [{ address = "172.16.5.1"; prefixLength = 31; }];
      networking.interfaces."rcon-mc".ipv4.addresses = [{ address = "10.254.2.1"; prefixLength = 31; }];
      networking.defaultGateway = "172.16.5.0";

      systemd.services.minecraft-server = {
        description = "Akitio MC Server Runtime";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          ExecStartPre = [
            # symlink the immutable static files from the Nix store
            "${pkgs.coreutils}/bin/ln -sf ${serverPackage}/* /srv/minecraft/"
            # if world folder doesn't exist on SSD, copy raw ZFS files instantly to restore state
            "${pkgs.bash}/bin/sh -c '[ ! -d /srv/minecraft/world ] && ${pkgs.coreutils}/bin/cp -a ${worldZfsPath} /srv/minecraft/world || true'"
          ];

          ExecStart = "${pkgs.jdk21_headless}/bin/java -Xmx5G -jar -Dfabric.addMods=mods fabric-server-mc.1.20.1-loader.0.16.9-launcher.1.0.1.jar";
          WorkingDirectory = "/srv/minecraft";
          Restart = "always";

          User = "nobody";
          Group = "nogroup";
          NoNewPrivileges = true;

          # strict sandboxing
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ProtectControlGroups = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          RestrictNamespaces = true;
          RestrictRealtime = true;
          MemoryDenyWriteExecute = true;
          SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
          SystemCallArchitectures = "native";
          RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX";
        };
      };
    };
  };

  # ----------------------------------------------------------------------------------------
  # container 2: ttyd rcon console (private access)
  # ----------------------------------------------------------------------------------------
  containers."mc-ttyd-rcon" = {
    autoStart = true;
    ephemeral = true;
    privateNetwork = true;
    interfaces = [ "ttyd-eth0" "rcon-ttyd" ];

    config = { config, pkgs, ... }: {
      system.stateVersion = "25.11";
      networking.interfaces."ttyd-eth0".ipv4.addresses = [{ address = "10.1.4.1"; prefixLength = 31; }]; # vpn-edge
      networking.interfaces."rcon-ttyd".ipv4.addresses = [{ address = "10.254.2.0"; prefixLength = 31; }]; # lateral to rcon-mc
      networking.defaultGateway = "10.1.4.0";

      systemd.services.ttyd-console = {
        description = "Akitio Web Terminal";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          ExecStart = "${pkgs.ttyd}/bin/ttyd -p 7681 ${pkgs.mcrcon}/bin/mcrcon -H 10.254.2.1 -P 25575 -p ${rconPassword}";
          Restart = "always";

          # strict Sandboxing
          User = "nobody";
          Group = "nogroup";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          RestrictNamespaces = true;
          SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
        };
      };
    };
  };

  # ----------------------------------------------------------------------------------------
  # service: zfs synchronized world backup
  # ----------------------------------------------------------------------------------------
  systemd.services."akitio-world-sync" = {
    description = "Sync and Snapshot Akitio World to ZFS Datastore";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      echo "Freezing Minecraft World..."
      ${pkgs.systemd}/bin/systemd-run -M mc-server --quiet --pipe --wait \
        ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25575 -p "${rconPassword}" "save-off" "save-all flush"

      sleep 5

      echo "Syncing SSD world to ZFS HDD..."
      ${pkgs.rsync}/bin/rsync -a --delete ${workingTreeDir}/world/ ${worldZfsPath}/

      echo "Taking atomic ZFS snapshot..."
      /run/current-system/sw/bin/zfs snapshot ${worldDataset}@mc-sync-$(date +%Y%m%d-%H%M%S)

      echo "Resuming World Saving..."
      ${pkgs.systemd}/bin/systemd-run -M mc-server --quiet --pipe --wait \
        ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P 25575 -p "${rconPassword}" "save-on"
    '';
  };

  systemd.timers."akitio-world-sync" = {
    description = "Daily Timer for Akitio World Sync";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true;
    };
  };

}
