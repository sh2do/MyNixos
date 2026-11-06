# MyNixos

NixOS flake config: niri with a hand-built rice (Quickshell bar, rofi menus, matugen colours from rotating wallpapers, video lock and login screens), NVIDIA, Home Manager.

## Layout

```
flake.nix / flake.lock        flake entry point (host: nixos)
configuration.nix             system config; imports modules/
hardware-configuration.nix    generated hardware config
hp-wmi-omen.nix               HP Omen hp-wmi kernel module
modules/
  desktop.nix                 packages and services for the rice
  home.nix                    Home Manager entry; imports the per-user modules
  niri/                       niri config split by block (KDL), deployed by HM
  theme/                      rice-wall + matugen templates (niri, rofi, foot, starship, python)
  terminal/                   foot, fastfetch, first-terminal fetch for fish
  rofi/                       launcher theme and rice-menu (apps, clipboard, power, wifi, ...)
  shell/                      Quickshell bar: top pill, auto-hide bottom bar with the python, OSD, notifications
  lock/                       Quickshell video lock screen, rice-lock, swayidle
  sddm/                       SDDM video login theme
  look/                       polkit agent, cursor, icon and GTK themes (every session)
tests/                        bash tests for the rice scripts (bash tests/<name>-test.sh)
docs/superpowers/             design spec and implementation plan
dotfiles/                     older ghostty, niri, nvim configs (reference only)
```

For the full guide (theming flow, every key, menus, lock and recovery, adding wallpapers, tests and roadmap), see **[docs/RICE.md](docs/RICE.md)**.

## How the theming works

`rice-wall` owns the wallpaper. It picks from `~/.local/share/wallpapers/rotation`, shows it with awww, and runs matugen, which rewrites the colour files in `~/.config` and `~/.cache/rice`. Everything else (niri borders, the bar, rofi, foot, starship, the python) reads those files. A systemd user timer runs `rice-wall next` every 45 minutes.

## Keys

| Key | Action |
| --- | --- |
| `Mod+Space` | launcher |
| `Mod+Alt+V` | clipboard history |
| `Mod+Shift+Q` | power menu |
| `Mod+Alt+W` / `Mod+Ctrl+W` | next wallpaper / wallpaper picker |
| `Mod+T` | foot (floating) |
| `Super+Alt+L` | lock (also after 5 min idle; screens off at 10 min) |

## Rebuild

```sh
nh os switch
# or: sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

## Recovery

- Lock screen stuck: switch to a TTY (`Ctrl+Alt+F3`), log in and run `loginctl unlock-sessions` as root.
- Login screen broken: from a TTY, `sudo nixos-rebuild switch --rollback`.

## Fresh install

```sh
git clone git@github.com:sh2do/MyNixos.git /etc/nixos
sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```
