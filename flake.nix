{
  description = "NixOS configuration: niri with a custom Quickshell rice";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Needed for the Home Manager block in configuration.nix
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        # home-manager is imported in configuration.nix, not repeated here.
        ./configuration.nix
        inputs.silentSDDM.nixosModules.default
      ];
    };
  };
}

