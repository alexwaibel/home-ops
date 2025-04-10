{
  description = "A NAS server running NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  };

  outputs = { self, nixpkgs, disko, nixos-facter-modules, ... }@inputs: {
    nixosConfigurations.nix-nas = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./machines/nas/configuration.nix
        nixos-facter-modules.nixosModules.facter
        {
          config.facter.reportPath =
            if builtins.pathExists ./facter.json then
              ./facter.json
            else
              throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";
        }
      ];
    };
  };
}

