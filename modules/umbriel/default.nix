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
    "9568vx.jpg" = "sha256-2FMvWIjeTTtSmVzjQdBh6ImLVrJ6raSQaV+VvGiUNuQ="; # crow
    "dgv8qo.png" = "sha256-l4+frb7yTY0ZlO+5R7eIY/K4L6/58+/0H4UozQknQF4="; # crow
    "o3z85l.png" = "sha256-EgGWa2brBcfjA4/H4N80HpDaA/AHhntt3Rf7Iy06mII="; # dark forest under the moon
    "weyjpp.jpg" = "sha256-NtJlTerF+TQ8E5zjQ93/ezYDwuM5JC2xS90nlrxxa10="; # snake
    "wq9epq.png" = "sha256-rYJrV/mnvRvQvbhDM4H+5rBywNi5oDBzmt7BOaX1yw8="; # snake
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
        type == "directory" || lib.any (ext: lib.hasSuffix ext path) [ ".qml" ".js" ".glsl" ".frag" ".vert" ".json" ".svg" ];
    }} $out
    chmod -R u+w $out
    # The phone link is the niri bar's (modules/shell); both shells poll it.
    cp ${../shell/Phone.qml} $out/Phone.qml
    cp ${../shell/phone.js} $out/phone.js
    # So is the weather (modules/weather), which both scenes follow.
    cp ${../shell/Weather.qml} $out/Weather.qml
    cp ${../shell/weather.js} $out/weather.js
    cp ${../shell/Sound.qml} $out/Sound.qml
    cp ${../shell/sound.js} $out/sound.js
    cp ${../shell/Focus.qml} $out/Focus.qml
    cp ${../shell/focus.js} $out/focus.js
    for f in $out/*.frag $out/*.vert; do
      qsb --qt6 -o "$f.qsb" "$f"
    done
  '';
in
{
  imports = [ inputs.umbriel.homeModules.default ];

  # slurp: the region screenshot bind (grim and wl-copy are already installed).
  home.packages = [ pkgs.slurp pkgs.kitty pkgs.kew pkgs.cava umbriel-wall ];

  home.file = lib.mapAttrs' (name: hash:
    lib.nameValuePair ".local/share/wallpapers/umbriel/${name}" { source = wallhaven name hash; }
  ) walls;

  # The Quickshell config "umbriel", started by autostart below.
  xdg.configFile."quickshell/umbriel".source = shell;

  # Slate terminal stack. kitty, starship and cava are only pointed at these
  # inside Umbriel: STARSHIP_CONFIG is set on Umbriel's own kitty launches (the
  # Mod+T bind and the launcher), never in Umbriel's `environment`, which goes to
  # the systemd user manager and would leak into a niri login after it. kew has
  # no path switch, so its theme sits in its own themes dir and is picked inside
  # kew.
  xdg.configFile."umbriel-term/kitty.conf".source = ./kitty-umbriel.conf;
  xdg.configFile."umbriel-term/starship.toml".source = ./starship-umbriel.toml;
  xdg.configFile."umbriel-term/kew.conf".source = ./kew.conf;
  xdg.configFile."umbriel-term/cava.conf".source = ./cava.conf;
  xdg.configFile."kew/themes/umbriel.theme".source = ./kew.conf;

  # A running shell keeps watching the old store path, so a switch never reaches
  # it (as with the niri bar, modules/shell/default.nix). Restart it inside the
  # live Umbriel session when its files changed: the socket is
  # umbriel-$WAYLAND_DISPLAY.sock, and stale ones (left by nested test
  # sessions) don't answer.
  home.activation.restartUmbrielShell = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    old=$(readlink -f "''${oldGenPath:-/nonexistent}/home-files/.config/quickshell/umbriel" || true)
    new=$(readlink -f "$newGenPath/home-files/.config/quickshell/umbriel")
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    if [ "$old" != "$new" ]; then
      for sock in "$XDG_RUNTIME_DIR"/umbriel-*.sock; do
        [ -S "$sock" ] || continue
        if UMBRIEL_SOCKET="$sock" ${config.programs.umbriel.package}/bin/umbriel msg spawn true >/dev/null 2>&1; then
          run ${pkgs.quickshell}/bin/qs kill -c umbriel >/dev/null 2>&1 || true
          run env UMBRIEL_SOCKET="$sock" ${config.programs.umbriel.package}/bin/umbriel msg spawn qs -c umbriel
          break
        fi
      done
    fi
  '';

  # The effect shaders, next to config.toml so its relative paths resolve.
  xdg.configFile."umbriel/effects".source = ./effects;

  programs.umbriel = {
    enable = true;
    settings = {
      # cliphist: niri starts the same watcher, so the clipboard menu has history
      # in both sessions. kdeconnectd: the phone link (configuration.nix), so
      # phone notifications arrive from login on.
      general.autostart = [ "qs -c umbriel" "wl-paste --watch cliphist store" "kdeconnectd" ];
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

      # Umbriel's terminal (class umbriel-term) floats, centred, at niri's foot size.
      window_rule = [
        {
          match.app_id = "^umbriel-term$";
          default_floating = true;
          default_floating_size_px = { width = 1100; height = 680; };
        }
      ];

      # Film grain over the screen (static, see grain.glsl), and windows that
      # bleed in and drain out like ink in water (every window: Umbriel's open
      # and close animation is global). The shell switches the grain off on
      # eDP-2 while a fullscreen window is focused (UmbrielIpc.qml). max_fps
      # caps the frames an effect asks for on its own.
      effects = {
        preset = {
          grain = { kind = "screen"; shader = "effects/grain.glsl"; };
          ink-in = { kind = "animation"; shader = "effects/ink-in.glsl"; };
          ink-out = { kind = "animation"; shader = "effects/ink-out.glsl"; };
        };
        screen = "grain";
        max_fps = 24;
      };
      animation = {
        windows_in = { effect = "ink-in"; duration_ms = 380; curve = "easeout"; };
        windows_out = { effect = "ink-out"; duration_ms = 260; curve = "easeout"; };
      };
    };
  };
}
