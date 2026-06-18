# note for hardware-configuration.nix
# make sure "r8169" is in this list alongside your storage/usb drivers:
# this is so initrd ssh works over network
# boot.initrd.availableKernelModules = [ ... "r8169" ];

{ config, pkgs, stable, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./networking.nix
      ./modules/michel/default.nix
      ./modules/frangisk.nix
      ./modules/eligius/default.nix
    ];

  # --------------
  # --- system ---
  # --------------

  networking.hostName = "pluto";
  # networking.hostId = "8_char_id"; # required for zfs — generate w/ `head -c 8 /etc/machine-id`

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_6_6;
  # boot.supportedFilesystems = [ "zfs" ];
  # boot.kernelParams = [ "zfs.zfs_arc_max=4294967296" ]; # limit ZFS ARC to 4GB to reserve RAM

  # WAKE-ON-LAN (WOL)
  networking.interfaces."eth0".wakeOnLan.enable = true;

  # this starts a tiny SSH server during boot just in case the OS hangs.
  # boot.initrd.network.enable = true;
  # boot.initrd.network.ssh = {
  #   enable = true;
  #   port = 2222; # access via: ssh -p 2222 root@server-ip

  #   initrd logs in as root.
  #   authorizedKeys.keys = [
  #     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG9eRu62f80hkD8XiGxX//3dJsVz/lzhuEMhnqT154Ea venus-pluto"
  #   ];
  # };

  # ALFA AWUS036ACH Wi-Fi adapter
  boot.extraModulePackages = [ config.boot.kernelPackages.rtl8812au ];
  boot.kernelModules = [ "8812au" ];
  networking.networkmanager.enable = true;

  # ----------------
  # --- hardware ---
  # ----------------

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.rasdaemon.enable = true;

  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 8192;
  }];

  # -------------
  # --- users ---
  # -------------

  users.users.liabri = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];

    openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG9eRu62f80hkD8XiGxX//3dJsVz/lzhuEMhnqT154Ea venus-pluto"
    ];
  };

  security.sudo = {
    enable = true;
    extraRules = [
      {
        users = [ "liabri" ];
        commands = [
          # allow running all custom ZFS scripts without a password
          {
            command = "/run/current-system/sw/bin/unlock-muzika";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/lock-muzika";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };

  # ----------------
  # --- packages ---
  # ----------------

  environment.systemPackages = with pkgs; [
    curl
    fastfetch		# system info
    btop		    # system monitor
    lm_sensors      # read CPU temps
    edac-utils      # read ECC memory errors
    rasdaemon       # detects, corrects & logs hardware error

    git             # temp for dev

    # zfs lock/unlock of ro datasets
    # (writeScriptBin "unlock-muzika" ''
    #   #!${yash}/bin/yash
    #   zfs set readonly=off mahzen/muzika
    #   (sleep 900 && zfs set readonly=on mahzen/muzika) &
    # '')
    # (writeScriptBin "lock-muzika" ''
    #   #!${yash}/bin/yash
    #   zfs set readonly=on mahzen/muzika
    # '')
  ];

  # ----------------
  # --- services ---
  # ----------------

  # enables weekly TRIM for ext4 SSD to maintain lifespan and speed
  services.fstrim.enable = true;

  # enables regular ZFS scrubbing to detect and repair bit-rot on HDDs
  # services.zfs.autoScrub.enable = true;
  # services.zfs.autoScrub.interval = "weekly";

  services.xserver.xkb = {
      layout = "gb";
      variant = "";
  };

  # ssh
  services.openssh = {
    enable = true;

    settings = {
      PasswordAuthentication = false;   # security best practice: Disable passwords, use SSH keys only
      PermitRootLogin = "no";           # disable root login over SSH

      # restrict access to your user, only from specific subnets.
      AllowUsers = [
        "liabri@192.168.*.*"   # local LAN subnet
        "liabri@10.8.0.*"      # router's vpn subnet
        "liabri@127.0.0.1"     # localhost
        "liabri@10.100.0.*"    # vpn
      ];
    };
  };

  # -------------------
  # --- environment ---
  # -------------------

  # shell
  environment.shells = with pkgs; [ yash ];

  # locale
  time.timeZone = "Europe/Rome";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocales = [ "en_US.UTF-8/UTF-8" ];
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };


  environment.shellAliases = {
    # --- container monitoring & state ---
    cls  = "machinectl list";
    cs  = "machinectl status";       # Usage: cs <container>
    creb  = "sudo machinectl reboot";    # Usage: creb vpn-edge
    cex = "sudo machinectl exec"; # Usage: cex <container> <command>
    ckill = "sudo machinectl terminate"; # force-kill a completely locked container
    csh  = "sudo machinectl shell";   # Usage: csh <container>
    clog = "sudo machinectl login";   # Usage: clog <container>
    cl  = "journalctl -M";           # Usage: cl <container>
    cll = "journalctl -f -M";        # Usage: cll <container> (Follow live)

    # --- specific containers & services ---
    mlup = "sudo cp -r /home/liabri/pluto/etc/nixos/modules/michel /etc/nixos/modules/";
    rproxyl = "journalctl -M rproxy-edge -u caddy -f";
    wgl   = "journalctl -M vpn-edge -u wireguard-wg0 -f";
    wgs = "sudo systemctl -M vpn-edge status wireguard-wg0";

    statsl = "journalctl -u generate-web-stats.service -f";
    statsr = "sudo systemctl start generate-web-stats.service";

    esup = "sudo cp -r /home/liabri/pluto/etc/nixos/modules/eligius /etc/nixos/modules/";
    gitsshl  = "journalctl -M git-ssh -u sshd -f";
    gitwebs = "systemctl -M git-web status cgit-go-bridge";

    fkup = "sudo cp -r /home/liabri/pluto/etc/nixos/modules/frangisk.nix /etc/nixos/modules/";
    dkrml = "journalctl -M lbmt-darkroom -u static-web-server -f";
    dkrms = "systemctl -M lbmt-darkroom status static-web-server";

    # --- nix ---
    conup = "sudo cp -r /home/liabri/pluto/etc/nixos/configuration.nix /etc/nixos/configuration.nix";
    flakeup = "sudo cp -r /home/liabri/pluto/etc/nixos/flake.nix /etc/nixos/flake.nix";
    rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#${config.networking.hostName}";
    nix-hist  = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
    nix-clean = "sudo nix-collect-garbage -d && nix-store --gc";
  };

  # -----------------
  # --- nix stuff ---
  # -----------------

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true; # deduplication of nix-store

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.autoUpgrade = {
    enable = true;
    allowReboot = false; # keeps your uptime; you decide when to actually reboot
  };

  system.stateVersion = "26.05";
}
