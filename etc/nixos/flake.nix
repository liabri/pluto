{
  description = "multi-channel";

  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, ... }@sources: {
    nixosConfigurations = {
      pluto = nixpkgs-stable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit sources; };
        modules = [ ./hosts/venus/configuration.nix ];
      };
    };
  };
}
