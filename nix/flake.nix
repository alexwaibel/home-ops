{
  description = "My home infrastructure running NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  };

  outputs = { self, nixpkgs, disko, nixos-facter-modules, ... }@inputs: {
    nixosConfigurations = {
      nas = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./machines/nas/configuration.nix
          nixos-facter-modules.nixosModules.facter
          {
            config.facter.reportPath =
              if builtins.pathExists ./machines/nas/facter.json then
                ./machines/nas/facter.json
              else
                throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./machines/nas/facter.json`?";
          }
        ];
      };
      media-center = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./machines/media-center/configuration.nix
          nixos-facter-modules.nixosModules.facter
          {
            config.facter.reportPath =
              if builtins.pathExists ./machines/media-center/facter.json then
                ./machines/media-center/facter.json
              else
                throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./machines/media-center/facter.json`?";
          }
        ];
      };
    };
  };
}
