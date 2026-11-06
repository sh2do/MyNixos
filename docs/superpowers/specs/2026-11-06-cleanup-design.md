# Cleanup after the niri rice

Date: 2026-11-06
Status: approved in conversation, awaiting doc review

## Why

The niri rice (plan `docs/superpowers/plans/2026-11-06-niri-rice.md`) is finished. An audit of `/etc/nixos` and `~/.config/niri` found a few missing basics and some leftovers from the Noctalia, DMS and Umbriel era. This job fixes those before the next two jobs (the python, then the Umbriel desktop) build on top.

## Goals

1. **Add a polkit authentication agent.** No agent runs today, so actions that need admin rights (Nautilus mounting a drive, `fwupdmgr`, anything that asks through polkit) fail without showing a prompt.
   - It must start in every graphical session: niri now, Umbriel later.
   - *My call:* `polkit_gnome`'s agent, run as a Home Manager systemd user service `WantedBy`/`PartOf` `graphical-session.target`.
2. **Declare the cursor, icon and GTK themes in Home Manager.** Today they're only picked by hand in nwg-look, so a fresh install looks stock.
   - *My call:*
     - cursor `Bibata-Modern-Classic`, size 24, matching `XCURSOR_SIZE` in `modules/niri/misc.kdl`
     - icons `Papirus-Dark`
     - GTK theme `adw-gtk3-dark`
     - keep the existing `prefer-dark` dconf setting
   - Set them through `home.pointerCursor` and `gtk.*`, so GTK apps, Xwayland apps and both compositors agree.
   - Also set `xcursor-theme` in niri's `cursor { }` block (`modules/niri/misc.kdl` sets only the size today), and the cursor theme for the SDDM greeter in `modules/sddm/default.nix`, so the login screen matches.
   - **Font.** nwg-look's `settings.ini` sets `gtk-font-name=Inter Variable 11`, but Inter isn't installed. *My call:* `gtk.font` = Rubik 11 (Rubik is already in `fonts.packages`).
   - **nwg-look.** Once Home Manager owns `settings.ini`, nwg-look can't save. *My call:* remove `nwg-look` from `configuration.nix` and keep `dconf-editor`.
   - **Stale GTK CSS.** `~/.config/gtk-3.0` and `~/.config/gtk-4.0` hold unmanaged DMS/Noctalia CSS: `gtk.css` importing `dank-colors.css`, plus `dank-colors.css`, `noctalia.css`, `noctalia-extensions.css` and `thunar.css`. Nothing regenerates it.
     - *My call:* delete those files, which is part of the step 5 confirmation.
     - Add a small matugen template (`modules/theme/templates/gtk.css`, registered in `matugen.toml`) that sets libadwaita's named colours (accent, window/view/headerbar/card backgrounds and foregrounds) from the wallpaper palette.
     - Have Home Manager not write `gtk.css` itself, so the matugen output in `~/.config/gtk-3.0/` and `gtk-4.0/` wins.
     - GTK apps then follow the wallpaper like everything else in the rice.
3. **Fix `Configs/` in git.** It's a nested git repo committed as a gitlink with no `.gitmodules`, so a fresh clone gets an empty folder. It's an old copy of the config.
   - *My call:* untrack it (`git rm --cached Configs`) and add `Configs/` to `.gitignore`.
   - The folder stays on disk untouched.
4. **Remove dead weight from `configuration.nix`:**
   - `zsh`: the login shell is fish.
   - `fetch`: fastfetch is the one in use.
   - The empty `environment.systemPackages = [ ];` in `modules/desktop.nix`: delete the empty list and keep the PAM line.
   - `dotfiles/ghostty/themes/dankcolors`: a DMS-generated theme. Check whether `dotfiles/ghostty/config*` references it first, and remove the reference too if so.
5. **Delete leftover files.** The user approved deleting these, but confirm once more before running the delete, since they're outside the repo:
   - `~/.config/niri/common.kdl`, `~/.config/niri/dms/` and `~/.config/niri/dms-theme-sync.kdl`. Nothing includes them: `config.kdl` only includes the six module files and `colors.kdl`.
   - The empty folders `/etc/nixos/umbriel/` and `/etc/nixos/wallpapers/`.

## Non-goals

- **Not removing ghostty or kitty.** `programs.tmux` still has a ghostty terminal override and `dotfiles/ghostty` is kept as reference. *My call:* keep both; they're cheap.
- Not touching `hp-wmi-omen.nix`, `boot.extraModulePackages`, the Python/nvim deps or `programs.nix-ld`.
- Not changing the rice's look, apart from GTK apps now following the wallpaper colours. Before, they were frozen at old DMS colours.

## Constraints

- The flake only sees git-tracked files. `git add` new files before `nix build`.
- Build check without sudo: `nix build /etc/nixos#nixosConfigurations.nixos.config.system.build.toplevel --no-link`.
- The user switches with `! nh os switch`. Never run sudo.
- `bash tests/*-test.sh` and `niri validate` must still pass.

## Done when

- Running `pkexec true` in the niri session shows a password prompt.
- A GTK app, an Xwayland app, the niri desktop and the SDDM login screen all show the same cursor.
- After `rice-wall next`, Nautilus picks up the new accent and background colours.
- A fresh `git clone` builds and has no `Configs` entry.
- `rg -n 'zsh|\bfetch\b|dankcolors'` over `configuration.nix`, `modules` and `dotfiles` shows nothing unexpected.
- The listed leftover files are gone.

## Left to the builder

- The exact polkit agent package attribute and service wiring.
- Whether to put the theme settings in `modules/home.nix` or a new `modules/look/` module.
