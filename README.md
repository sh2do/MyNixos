# MyNixos

NixOS flake config: niri with a hand-built rice (Quickshell bar, rofi menus, matugen colours from rotating wallpapers, video lock and login screens), a second dark session on the Umbriel compositor, NVIDIA, Home Manager.

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
  umbriel/                    the Umbriel session: config, keybinds, effect shaders, umbriel-wall,
                              slate terminal stack, shell/ (Quickshell "umbriel": island, chain,
                              launcher, live wallpapers)
tests/                        bash and node tests for the rice scripts (bash tests/<name>-test.sh)
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

## Umbriel desktop

A second session next to niri, on the [Umbriel](https://github.com/noctalia-dev/umbriel) compositor: dark, quiet and slate-grey, with its own wallpapers and no matugen. niri is untouched; pick either one at login.

- **Pick it at login:** on the login screen, the session name sits under the password field (`‹  niri  ›`). Press Left or Right (or click it) until it reads **Umbriel**, then type the password. It starts on the last session used, so pick **niri** the same way to go back.
- **What's there:** chain-link workspaces top-left, an island top-centre (clock, music, volume and brightness OSD, notifications), faint status bottom-right, a launcher that drops out of the island, live rain and storm wallpapers, film grain over the screen (off while a fullscreen window is focused) and windows that open and close through smoke.
- **Keys:** the same as niri wherever Umbriel has an equivalent (`modules/umbriel/binds.nix`). `Mod+Shift+/` shows them all.

| Key | Action |
| --- | --- |
| `Mod+Space` | launcher |
| `Mod+Ctrl+W` | wallpaper picker |
| `Mod+Alt+V` / `Mod+Shift+Q` | clipboard history / power menu (the rofi menus) |
| `Mod+T` | foot, with the slate theme |
| `Mod+F` / `Mod+Shift+F` | maximise / fullscreen |
| `Super+Alt+L` | lock (the shared `rice-lock`) |
| `Mod+Shift+E` | quit the session |

- **Wallpapers:** `umbriel-wall` remembers which of `~/.local/share/wallpapers/umbriel` the shell shows. There is no rotation. `umbriel-wall list` prints the ids, `umbriel-wall current` the one in use and `umbriel-wall set ID` switches (the picker calls this). `xe9223` (hydrangea in the rain) and `jeyo1m` (storm) are live.
- **Check the config:** `umbriel config validate`.

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
