# Niri rice from scratch — design

Date: 2026-11-06
Repo: `/etc/nixos` (NixOS flake, host `nixos`, user `Zaion`, Home Manager as a NixOS module)

## Intent

Replace the current Noctalia / Umbriel / DMS stack with a plain niri desktop built from scratch.
The user wants something that "feels like me": nice to look at, simple to live with, with a few
tasteful animations. They will rice it further themselves, so every piece must be easy to read and edit.
It should also use less RAM: Noctalia (~220 MB) and the mpvpaper live wallpaper (~290 MB) are currently resident.

Mood: rainy, dusky, purple and blue. The wallpaper the user kept coming back to is a rainy hydrangea
scene, and their favourite rotation is all purple and blue.

## Goals

1. Plain niri as the only session. Remove Noctalia, Umbriel, DMS, the "Niri + DMS" session,
   umbriel-extras, and their flake inputs and packages.
2. Static wallpapers that rotate, with every UI colour following the current wallpaper.
3. A custom Quickshell shell (bar, lock screen, OSD) written from scratch for this setup.
4. Quick toggles for wifi, bluetooth, volume, brightness and power profile, plus a lock screen
   and automatic locking when idle.
5. A themed rofi launcher and menus.
6. A foot terminal with a new fastfetch and a new starship prompt.
7. A new login screen with a live (video) background.
8. Lower resident RAM than today.

## Non-goals

- Umbriel. It is planned as a separate later project, also built from scratch. Don't build it here,
  but leave room for `modules/umbriel/`.
- Touchpad gestures. Scrapped by the user.
- Vines or other decoration painted into the wallpapers. Scrapped.
- Recreating any existing rice. shin, sonamu and Lysec's setups were inspiration only.

## Anti-goals (failure even if it works)

- A hyper-compact bar with tiny text. The user disliked that in shin and Lysec's setups.
- Something complicated to maintain, or a sprawling shell that grows back to Noctalia's size.
- Breaking Steam or games. XWayland must keep working through `xwayland-satellite`, as it does now.
- A live wallpaper on the desktop. Static only, for performance. Live video is wanted only on the
  login and lock screens.

## Current state (relevant facts)

- `configuration.nix` holds everything, including the Home Manager block. `flake.nix` has inputs
  `noctalia`, `umbriel`, `xdg-desktop-portal-umbriel`, `dms`, `silentSDDM`, `home-manager`,
  `antigravity-nix` and `nixpkgs` (unstable).
- niri 26.04. The niri config is NOT managed by Nix. It lives in `~/.config/niri/` (`config.kdl`
  includes `common.kdl`, which is shared with the DMS session). A copy sits in `dotfiles/niri/`.
- `common.kdl` already starts `mpvpaper` and a nonexistent `waybar`, binds volume and brightness to
  `wpctl` and `brightnessctl`, and binds `Super+Alt+L` to `swaylock`, which isn't installed.
- Services already on: NetworkManager, bluetooth + blueman, pipewire, power-profiles-daemon, upower.
- Already installed: quickshell, matugen 4.2, foot, ghostty, fastfetch, brightnessctl, cava,
  bluetuith, pwvucontrol, grim, swappy, wl-clipboard, cliphist, starship (`programs.starship`), fish.
- Not installed: swww, rofi, swayidle, playerctl.
- SilentSDDM (catppuccin-mocha theme, `greeter.mp4` and `lockscreen.mp4` video backgrounds) is the
  current display manager.
- `~/Videos` holds seven older live-wallpaper clips (including `blue-scenery-live-wallpaper.mp4`). They aren't needed for this build.
- Uncommitted work in the tree (`hp-wmi-omen.nix`, Python and nvim deps). Leave it intact.

## Decided by the user

### Session and structure
- Plain niri only.
- Add a `modules/` folder. niri config goes in `modules/niri/`, and Umbriel's later in `modules/umbriel/`.
  Do this during the build, not before.

### Wallpapers and colour
- Static wallpapers via `swww`, with fade transitions.
- Rotation set (the user's picks, from wallhaven):
  - `xe9223` https://w.wallhaven.cc/full/xe/wallhaven-xe9223.jpg (rain + hydrangea)
  - `3kql73` https://w.wallhaven.cc/full/3k/wallhaven-3kql73.jpg (purple hydrangea close-up)
  - `dpo88l` https://w.wallhaven.cc/full/dp/wallhaven-dpo88l.jpg (purple rainy street)
  - `rr8vx7` https://w.wallhaven.cc/full/rr/wallhaven-rr8vx7.jpg (purple rainy street)
  - `x6kvq3` https://w.wallhaven.cc/full/x6/wallhaven-x6kvq3.png (dusk town)
  - `xe93pd` https://w.wallhaven.cc/full/xe/wallhaven-xe93pd.png (purple landscape)
- Colours come from the current wallpaper via `matugen` and recolour the shell, rofi, foot,
  starship and the niri borders.

### Shell: custom Quickshell (not Waybar)
Chosen because Waybar can't animate images or auto-hide on mouse hover under niri.
- **Top:** a small centred pill showing the focused app's title. While media is playing, it
  switches to the track (artist and title).
- **Bottom:** an auto-hide bar. Slightly transparent. Slides in when the pointer touches the bottom
  edge and slides out after the pointer leaves. Contents follow the chosen "split" concept:
  workspaces | wifi, bluetooth, volume, brightness, power profile, battery | power button.
  Roomy sizing (bar ~36–40 px tall, ~13 px text), smooth hover fades.
- **Animated cobra:** a curled cobra lives on the bottom bar, animated with slow breathing,
  a hood sway and an occasional tongue flick. The art must be original (drawn for this project),
  not lifted from elsewhere.
- Clicking a toggle opens the matching rofi menu.
- The lock screen is part of the same Quickshell config (see below).

### Launcher and menus
- rofi (2.x, Wayland-native), themed from the wallpaper palette. Used for apps, wifi, bluetooth,
  power menu, clipboard history (cliphist) and a wallpaper picker with thumbnails.

### Terminal
- foot as the main terminal: partly see-through, thin borders, 12 px corner radius
  (inspired by sonamu's terminal).
- The terminal (and other utility apps) opens **floating at a set size**, not full screen.
- New fastfetch: an image logo (foot supports sixel) instead of the ASCII logo, designed fresh.
- fastfetch must NOT run in every new terminal. It runs only in the first terminal of a login
  session, and on demand with a short command (`ff`). Today it runs in `programs.fish.interactiveShellInit`.
- A new starship config from scratch. Two-line prompt, coloured from the wallpaper palette.

### Login and lock
- A new login screen with a live video background. SDDM remains the realistic route for video,
  so this means a new SDDM theme matched to the look. Replacing SilentSDDM is acceptable.
- Live clips (the user's picks, from MotionBGs, free):
  - *Aesthetic landscape with train*, https://motionbgs.com/aesthetic-landscape-with-train
    (HD mp4: `https://motionbgs.com/dl/hd/1432/`, ~1.2 MB; 4K: `/dl/4k/1432/`)
  - *Tokyo midnight rain*, https://motionbgs.com/tokyo-midnight-rain
    (HD mp4: `https://motionbgs.com/dl/hd/9963/`, ~2.6 MB; 4K: `/dl/4k/9963/`)
- Lock screen: custom Quickshell (`WlSessionLock`) with a live video background via QtMultimedia,
  because hyprlock and swaylock can't play video. `swayidle` (or equivalent) locks on idle and
  before suspend.

### Extras
- On-screen popups for volume and brightness when the keys are used.
- Notifications (Quickshell's notification server or a small daemon; see "Left to the builder").
- niri window open and close animations.

## Calls made by Claude (user may override)

- Rotation interval: 45 minutes, plus a key to skip to the next wallpaper.
- The earlier non-purple picks (golden ruins `gwm1dq`, `gwm1d7`, `jeyo1m`; courtyard `k8z1dq`;
  `9ogj2d`, `w5x266`, `zpp6mw`) are kept in a separate folder, outside the rotation.
- The clock moves from the top to the bottom bar, because the top pill now shows the app or track.
- Wallpapers are fetched by Nix (`fetchurl` with hashes) rather than committed, to keep the repo small.
  The existing tracked `.mp4` files can stay.
- Ghostty stays installed as a fallback but is no longer the default terminal.
- Keep using `matugen` (already installed) rather than adding wallust or pywal.
- **How the toggles behave:**
  - Left click acts directly: wifi on/off, bluetooth on/off, volume mute, brightness does nothing,
    power profile cycles power-saver → balanced → performance.
  - Scrolling adjusts volume and brightness.
  - Right click opens the rofi menu: wifi networks, bluetooth devices, audio output, or power profile list.
  - The clock and the power button open their own rofi menus on left click.
- **Colours strictly follow each wallpaper** (`matugen image … -t scheme-content --prefer saturation`).
  All six picks were checked: their matugen primary hues fall between 200° and 335° (blue to purple),
  so the mood holds without pinning.
- **SDDM uses a fixed palette**, generated at build time from `xe9223` (the rain + hydrangea pick).
  The greeter runs as its own user and can't read `~/.cache`.
- **Login screen gets the train landscape, lock screen gets Tokyo midnight rain.**
  Use the HD (1080p) files: the panel is 1920x1200 @ 144 Hz (eDP-2), so crop to fill, and HD keeps
  decoding cheap. Both clips are small, so commit them to the repo like the existing `.mp4`s, and
  remove the old `greeter.mp4` and `lockscreen.mp4` once the new screens work.
- **The fastfetch logo is the same original cobra art as the bar**, rendered as a still image, recoloured
  from the current palette, and written to a writable path on each wallpaper change.
- **Top pill floats over windows** (layer-shell overlay, no exclusive zone), but niri gets a top strut
  just big enough that windows start below it, so nothing is covered. The pill and the bottom bar hide
  while a window is fullscreen.

## Left to the builder

- How config files are owned: Home Manager `xdg.configFile` sources from `modules/…` (recommended,
  so niri and Quickshell config become declarative) vs symlinks. Matugen output that changes at
  runtime must live in writable paths (`~/.cache` or `~/.config/*/generated`), not the Nix store.
- Exact Quickshell file layout, and how matugen colours reach QML (a generated JSON or QML file is fine).
- The cobra format: SVG with QML animation, a sprite sheet, or animated WebP/APNG. Pick what looks
  best and stays cheap on CPU when the bar is hidden (pause the animation while hidden).
- Which SDDM theme to start from, or a hand-written QML theme. The look should match the shell.
- The notification approach, and the OSD styling.
- Keybinds for the new pieces, avoiding clashes with the existing `common.kdl` binds.
- Removing stale `~/.config/niri/*.backup*` files and the DMS include files.

## Success looks like

- Logging in via the new video login screen lands on niri with a purple wallpaper, the top pill
  and a hidden bottom bar that slides up with the cobra on hover.
- Wifi, bluetooth, volume, brightness and power profile can each be toggled in two clicks or fewer.
- Locking (key or idle) shows the video lock screen, and unlocking works.
- Steam and a game launch normally.
- Resident memory for the desktop shell, wallpaper daemon and idle tools is clearly below the
  current Noctalia + mpvpaper ~510 MB.
- `nixos-rebuild` succeeds from a clean checkout. `niri validate` passes.
