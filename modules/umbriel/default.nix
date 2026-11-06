# Umbriel: the second login session next to niri. The compositor and its
# portal come from the NixOS side (configuration.nix); this writes
# ~/.config/umbriel/config.toml. Check it with: umbriel config validate
{ config, inputs, lib, pkgs, ... }:

let
  # The terminal stack for this session lives apart from niri's matugen one.
  term = "${config.home.homeDirectory}/.config/umbriel-term";
in
{
  imports = [ inputs.umbriel.homeModules.default ];

  # slurp: the region screenshot bind (grim and wl-copy are already installed).
  home.packages = [ pkgs.slurp pkgs.kew pkgs.cava ];

  # The Quickshell config "umbriel", started by autostart below.
  xdg.configFile."quickshell/umbriel".source = lib.cleanSourceWith {
    src = ./shell;
    filter = path: type:
      type == "directory" || lib.any (ext: lib.hasSuffix ext path) [ ".qml" ".js" ".glsl" ".json" ".svg" ];
  };

  # Slate terminal stack. foot, starship and cava are only pointed at these
  # inside Umbriel (the bind and STARSHIP_CONFIG); kew has no path switch, so
  # its theme sits in its own themes dir and is picked inside kew.
  xdg.configFile."umbriel-term/foot.ini".source = ./foot-umbriel.ini;
  xdg.configFile."umbriel-term/starship.toml".source = ./starship-umbriel.toml;
  xdg.configFile."umbriel-term/kew.conf".source = ./kew.conf;
  xdg.configFile."umbriel-term/cava.conf".source = ./cava.conf;
  xdg.configFile."kew/themes/umbriel.theme".source = ./kew.conf;

  programs.umbriel = {
    enable = true;
    settings = {
      general.autostart = [ "qs -c umbriel" ];
      environment.STARSHIP_CONFIG = "${term}/starship.toml";
      # Umbriel's defaults are blue; these are the slate palette (Palette.qml).
      colors = {
        background = "#14161bff"; # raised
        text_primary = "#d6dbe3ff"; # text
        text_muted = "#7d8796ff"; # muted
        accent_primary = "#eef1f5ff"; # bright
        accent_secondary = "#7d8796ff"; # muted
        insert_hint = "#7d879640"; # muted, faint
        border = {
          focused = "#7d8796ff"; # muted
          unfocused = "#262a31ff"; # line
          outer = "#0a0b0eff"; # bg
        };
        overview.badge = "#7d8796ff";
        tab_bar = {
          background = "#0a0b0eff";
          text = "#7d8796ff";
          active = "#4a4f58ff"; # slate
          active_text = "#eef1f5ff";
          active_unfocused = "#262a31ff";
          active_unfocused_text = "#d6dbe3ff";
        };
      };
      keybinds = import ./binds.nix { inherit lib term; };
    };
  };
}
