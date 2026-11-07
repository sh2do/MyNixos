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
  theme/                      rice-wall + matugen templates (niri, rofi, foot, starship, drips)
  terminal/                   foot, fastfetch, first-terminal fetch for fish
  rofi/                       launcher theme and rice-menu (apps, clipboard, power, wifi, ...)
  shell/                      Quickshell bar: top pill, auto-hide bottom bar with koi or a raven, OSD, notifications
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

`rice-wall` owns the wallpaper. It picks from `~/.local/share/wallpapers/rotation`, shows it with awww, and runs matugen, which rewrites the colour files in `~/.config` and `~/.cache/rice`. Everything else (niri borders, the bar, rofi, foot, starship) reads those files. A systemd user timer runs `rice-wall next` every 45 minutes.

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
- **What's there:** chain-link workspaces top-left, an island top-centre (clock, music, volume and brightness OSD, notifications), faint status bottom-right, a launcher that drops out of the island, a horned viper hanging from the island, a raven on the status row, live rain and storm wallpapers, film grain over the screen (off while a fullscreen window is focused) and windows that bleed in and drain out like ink in water.
- **The viper:** a horned viper hangs head down from under the island, jaws open, with venom on its forward fang. The drip follows CPU load (read from `/proc/stat` every 2 s): a drop every 4 s when calm, every 0.6 s at full load. A drop falls from the fang and lands on a window's title-bar edge, or fades (over window content it falls a short way and fades with a tiny ring). It pulls up behind the pill while the launcher is open or the island shows anything but the clock (a song, a notice, the OSD), and comes back down 2 s after. For a fullscreen window it hisses first, then pulls up. (The launcher has its own viper, wound around it: that one slides out when the launcher opens and strikes when you launch something.) It flicks its tongue every 10-20 s. While it is away with nothing falling, its clock is stopped.
- **The raven:** a raven perches on the left end of the status row (bottom-right), with a hoard beside it. It breathes, blinks, looks about, now and then ruffles its feathers, and preens every few minutes. A pointer resting near it is watched after 2 s, then hopped at and pecked. A notice makes it turn to the island and caw; it then catches the notice's trinket (a ring or a coin) as it falls from the island and drops it into the hoard. Trinkets fade out after a while. After dark (21:00-06:00) it sleeps with its head tucked in; a notice wakes it for about 20 s. It hides for fullscreen, and stops while the screen is locked or off.
- **The raven's art:** `modules/umbriel/shell/RavenBody.qml` is generated; don't edit its paths by hand. Change the parts in `modules/umbriel/raven-art/art.js` (or the template `RavenBody.qml.in`), then run `nix run nixpkgs#nodejs -- modules/umbriel/raven-art/art.js && nix run nixpkgs#nodejs -- modules/umbriel/raven-art/gen-qml.js`. `art.svg` is a preview of the parts.
- **Debug and tuning:** `UMBRIEL_SERPENT_FPS` caps every viper and raven clock. `UMBRIEL_RAVEN_DEBUG=1` makes the raven ruffle and preen every 20 s, and makes it night for 30 s of every 2 minutes. `UMBRIEL_HIDDEN_DEBUG=1` shows the spider every 10 s. Start the shell with them, e.g. `qs kill -c umbriel; UMBRIEL_RAVEN_DEBUG=1 qs -c umbriel`.
- **CPU (nested, so only a guide):** the whole shell with viper and raven is about 3.3-4% of one core at rest (60 s mean 3.8%); the viper is about 3%, the raven about 0.6%. With a fullscreen window the shell is about 0.15%. The real-session figures are in [the checklist](docs/UMBRIEL-CHECKLIST.md#viper-and-raven).
- **Keys:** the same as niri wherever Umbriel has an equivalent (`modules/umbriel/binds.nix`). `Mod+Shift+/` shows them all.

| Key | Action |
| --- | --- |
| `Mod+Space` | launcher |
| `Mod+Ctrl+W` | wallpaper picker |
| `Mod+Alt+V` / `Mod+Shift+Q` | clipboard history / power menu (the rofi menus) |
| `Mod+T` | kitty, floating, with the slate theme |
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
