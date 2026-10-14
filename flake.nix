{
  description = "NixOS configuration with Noctalia, Umbriel and niri (Noctalia + DMS sessions)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Upstream moved to noctalia-dev/noctalia (the Umbriel and NixOS docs use
    # it; it provides programs.noctalia). The old noctalia-shell URL may still
    # redirect, but this is the canonical one.
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    umbriel = {
      url = "github:noctalia-dev/umbriel";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Screen sharing / screenshots through xdg-desktop-portal for Umbriel.
    xdg-desktop-portal-umbriel = {
      url = "github:noctalia-dev/xdg-desktop-portal-umbriel";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # DankMaterialShell, used by the "Niri + DMS" session.
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
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

