{ config, pkgs, lib, ... }:

let
    # ----------------------------------------------------------------------------------------
    # rust RAG engine
    # ----------------------------------------------------------------------------------------
    # Compile your advanced Rust RAG engine statically using musl
      aurielRustEngine = pkgs.pkgsStatic.rustPlatform.buildRustPackage {
        pname = "auriel-engine";
        version = "0.2.0";

        # Point this to the local directory containing your Cargo.toml and src/main.rs
        src = /opt/auriel-engine-src;

        # Run `nix-prefetch` or use lib.fakeHash initially to generate this hash
        cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

        # Keep it 100% optimized for your local Ryzen CPU
        CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
      };

in {

    systemd.services."container@ling-ai" = {
        after = [ "container@vpn-edge.service" ];
        requires = [ "container@vpn-edge.service" ];
    };

    # ----------------------------------------------------------------------------------------
    # container 1: ling-ai (private access)
    # ----------------------------------------------------------------------------------------
  containers."ling-ai" = {
    autoStart = true;
    ephemeral = true;
    privateNetwork = true;
    interfaces = [ "ling-ai-eth0" ];

    bindMounts = {
        "/app/lingwistika" = { hostPath = "/mahzen/docs/lingwistika"; isReadOnly = true; };
        "/var/lib/private/ollama" = { hostPath = "/var/lib/ollama-models"; isReadOnly = false; };
        "/var/lib/qdrant" = { hostPath = "/var/lib/auriel-vectordb"; isReadOnly = false; };
    };

    config = { config, pkgs, ... }: {
      system.stateVersion = "25.11";
      networking.firewall.allowedTCPPorts = [ 8000 ];
      networking.interfaces."ling-ai-eth0".ipv4.addresses = [{ address = "10.1.7.1"; prefixLength = 31; }];
      networking.defaultGateway = "10.1.7.0";

      # ollama server (port 11434)
      services.ollama.enable = true;

      # qdrant vector server (port 6333/6334)
      services.qdrant = {
        enable = true;
        settings = {
          storage.storage_path = "/var/lib/qdrant";
        };
      };

      # auriel engine (port 8000)
      systemd.services.auriel-engine = {
        description = "Auriel RAG Engine";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "ollama.service" "qdrant.service" ];

        serviceConfig = {
          ExecStart = "${aurielRustEngine}/bin/auriel-engine";
          Restart = "always";

          # Strict Sandboxing
          User = "nobody";
          Group = "nogroup";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          PrivateTmp = true;
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          RestrictNamespaces = true;
        };
      };
    };
  };
}
