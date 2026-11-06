# Umbriel: the second login session next to niri. The compositor and its
# portal come from the NixOS side (configuration.nix); this writes
# ~/.config/umbriel/config.toml. Check it with: umbriel config validate
{ inputs, lib, pkgs, ... }:

{
  imports = [ inputs.umbriel.homeModules.default ];

  # slurp: the region screenshot bind (grim and wl-copy are already installed).
  home.packages = [ pkgs.slurp ];

  programs.umbriel = {
    enable = true;
    settings = {
      keybinds = import ./binds.nix { inherit lib; };
    };
  };
}
