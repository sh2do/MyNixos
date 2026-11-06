# Umbriel: the second login session next to niri. The compositor and its
# portal come from the NixOS side (configuration.nix); this writes
# ~/.config/umbriel/config.toml. Check it with: umbriel config validate
{ config, inputs, lib, pkgs, ... }:

let
  # The terminal stack for this session lives apart from niri's matugen one.
  term = "${config.home.homeDirectory}/.config/umbriel-term";

  wallhaven = name: hash: pkgs.fetchurl {
    url = "https://w.wallhaven.cc/full/${builtins.substring 0 2 name}/wallhaven-${name}";
    inherit hash;
  };

  # Umbriel's own set, apart from niri's rotation. No rotation here: the
  # shell's picker chooses one and umbriel-wall remembers it.
  walls = {
    "xe9223.jpg" = "sha256-UKyiVtqLEQSs2W3os/9hMC/LYEbXEDQVl0FBaCIRRho="; # rain + hydrangea (live: rain)
    "jeyo1m.jpg" = "sha256-PS9kJhMk6B0Mg6jRKI/UCbyKmaihpgbv+YuUBIzKE2o="; # stormy ruins (live: storm)
    "mly2vm.png" = "sha256-wycdkm1EeVmqSj6IFex33TpCq7J+ts0q91y4/ToxwSo="; # red eclipse, fence and towers
    "neko5k.jpg" = "sha256-i9b1Bk5k//Zov8z9biSu3dIy7VneQHCBFp4y++UWeiY="; # crows over a pale moon
    "2e2xyx.jpg" = "sha256-fkAntypfN29UPYT7IbNnqdN7WZ5qYefn9C3Qt4BAuDE="; # vending machines, dim alley
    "427owm.jpg" = "sha256-DtXHTWhP/CfnfpnUs1gZG6fpWoYqBm+M+P4rmUTk/tU="; # Tokyo Tower, cherry blossom
    "rdrqz7.jpg" = "sha256-/0Lx4CDp+sblsBZonwB0Gw7Gc4I/b12+pl+8x0qLgZc="; # Tokyo Tower, blue hour
    "vqv3p8.jpg" = "sha256-tBmpzwMMIuvko89wHdAYS4gJQBCAVbGksxr/1GoNTt8="; # dusk over Tokyo
  };

  umbriel-wall = pkgs.writeShellApplication {
    name = "umbriel-wall";
    runtimeInputs = with pkgs; [ coreutils findutils gnused gnugrep ];
    text = builtins.readFile ./umbriel-wall.sh;
  };

  # The shell's QML plus its shaders, which Qt 6 only loads precompiled (.qsb).
  shell = pkgs.runCommand "umbriel-shell" { nativeBuildInputs = [ pkgs.kdePackages.qtshadertools ]; } ''
    cp -r ${lib.cleanSourceWith {
      src = ./shell;
      filter = path: type:
        type == "directory" || lib.any (ext: lib.hasSuffix ext path) [ ".qml" ".js" ".glsl" ".frag" ".json" ".svg" ];
    }} $out
    chmod -R u+w $out
    for f in $out/*.frag; do
      qsb --qt6 -o "$f.qsb" "$f"
    done
  '';
in
{
  imports = [ inputs.umbriel.homeModules.default ];

  # slurp: the region screenshot bind (grim and wl-copy are already installed).
  home.packages = [ pkgs.slurp pkgs.kew pkgs.cava umbriel-wall ];

  home.file = lib.mapAttrs' (name: hash:
    lib.nameValuePair ".local/share/wallpapers/umbriel/${name}" { source = wallhaven name hash; }
  ) walls;

  # The Quickshell config "umbriel", started by autostart below.
  xdg.configFile."quickshell/umbriel".source = shell;

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
