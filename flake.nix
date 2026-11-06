{
  description = "NixOS configuration: niri with a custom Quickshell rice, plus an Umbriel session";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Umbriel compositor: the second login session next to niri.
    umbriel = {
      url = "github:noctalia-dev/umbriel";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.xdg-desktop-portal-umbriel.follows = "xdg-desktop-portal-umbriel";
    };

    # Screen sharing / screenshots through xdg-desktop-portal for Umbriel.
    xdg-desktop-portal-umbriel = {
      url = "github:noctalia-dev/xdg-desktop-portal-umbriel";
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
      ];
    };
  };
}

