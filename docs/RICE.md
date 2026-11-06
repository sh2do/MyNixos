# The Rice

A from-scratch niri desktop on NixOS: rotating rainy wallpapers that recolour the whole desktop, a Quickshell bar with an animated snake, rofi menus, a floating foot terminal, and video lock and login screens. Everything is declared in this repo and deployed by Home Manager. Nothing is hand-edited in `~/.config`.

> Branch `niri-rice`. Designs and plans live in `docs/superpowers/` (see [Roadmap](#roadmap)).

---

## At a glance

| Piece | What you see | Where it lives |
| --- | --- | --- |
| Compositor | niri 26.04, scrolling columns, rounded floating terminals, eased open/close animations | `modules/niri/` |
| Wallpapers and colours | a curated rainy/purple rotation that changes every 45 min, with a fade; every colour in the desktop follows it | `modules/theme/` |
| Bar | a top pill (the playing song, or the focused window title) and an auto-hide bottom bar (workspaces, toggles, clock, power) with the snake | `modules/shell/` |
| Menus | a rofi launcher with a wallpaper image panel, plus wifi, bluetooth, audio, power-profile, power and clipboard menus | `modules/rofi/` |
| Terminal | foot, starship two-line prompt, fastfetch (snake logo) only in the first terminal | `modules/terminal/` |
| OSD and notifications | Quickshell volume and brightness OSD, toasts (critical ones stay) | `modules/shell/` |
| Lock | Quickshell lock with a Tokyo-rain video, locks after 5 min idle and before sleep | `modules/lock/` |
| Login | SDDM with a custom Qt6 theme: train landscape video, big clock, avatar | `modules/sddm/` |

## How the theming works

```
          45-min timer / Mod+Alt+W / picker
                        │
                        ▼
                    rice-wall ──▶ awww (shows the image, with a fade)
                        │
                        ▼
                     matugen  (Material You palette from the image)
                        │ writes
     ┌──────────┬───────┴──────┬───────────┬────────────┬─────────────┐
     ▼          ▼              ▼           ▼            ▼             ▼
 niri colors  rofi colors   foot colors  starship    colors.json   snake logo
   .kdl         .rasi          .ini        .toml     (bar, lock)  (fastfetch)
```

- **`rice-wall`** owns the wallpaper state. It is the only thing that writes it.
- **Everything else only reads** the files matugen writes. The bar and the lock re-read `~/.cache/rice/colors.json` live, and niri reloads `colors.kdl` by itself.
- **If matugen fails**, the wallpaper still changes and the old colours stay.

```sh
rice-wall next          # next wallpaper in the rotation
rice-wall pick          # choose one with rofi
rice-wall set PATH      # show a specific image (RICE_TRANSITION=grow for a grow-in)
rice-wall current       # print the current wallpaper path
```

### Adding a wallpaper

Wallpapers are fetched from Wallhaven by ID and pinned by hash in `modules/theme/default.nix`:

```nix
rotation = {
  "xe9223.jpg" = "sha256-…"; # rain + hydrangea
  # add: "<wallhaven id>.<ext>" = "<hash>";
};
```

Use `lib.fakeHash` first; the build error prints the real hash. `rotation` images are in the timer's cycle, and `saved` images only appear in the picker.

## Keys

`Mod` is the Super key. `Mod+Shift+/` shows niri's own overlay of every bind.

**Rice**

| Key | Action |
| --- | --- |
| `Mod+Space` | App launcher |
| `Mod+Alt+V` | Clipboard history |
| `Mod+Shift+Q` | Power menu |
| `Mod+Alt+W` | Next wallpaper |
| `Mod+Ctrl+W` | Wallpaper picker (a carousel that slides up) |
| `Super+Alt+L` | Lock |

**Apps**

| Key | App |
| --- | --- |
| `Mod+T` | foot (floating, 1100×680) |
| `Mod+D` | Firefox |
| `Super+E` | Nautilus |
| `Super+S` | Steam |
| `Super+Z` | Discord |
| `Super+X` | Kate |
| `Super+A` | Antigravity |

**Windows and workspaces** (niri defaults, kept)

| Key | Action |
| --- | --- |
| `Mod+H/J/K/L` or arrows | Focus left/down/up/right |
| `Mod+Ctrl+H/J/K/L` | Move the column or window |
| `Mod+1…9` / `Mod+Ctrl+1…9` | Go to / send to workspace |
| `Mod+U` / `Mod+I` | Workspace down / up |
| `Mod+R` | Cycle column width |
| `Mod+F` / `Mod+Shift+F` / `Mod+M` | Maximise column / fullscreen / maximise to edges |
| `Mod+O` | Overview |
| `Mod+Q` | Close window |
| `Mod+[` `Mod+]` `Mod+,` `Mod+.` | Consume or expel windows into or out of columns |

Media, volume and brightness keys work even on the lock screen.

## Menus

```sh
rice-menu apps | wifi | bluetooth | audio | profile | power | clipboard | wallpaper
```

All menus share the wallpaper-coloured rofi theme. Escape always does nothing.

## Bar

- **Top pill:** the playing song while music plays, otherwise the focused window's title. Fullscreen windows hide it.
- **Bottom bar:** auto-hides into a 3 px strip at the screen edge. Touch the edge to slide it up. `RICE_BAR_PINNED=1 qs -c rice` keeps it up while you restyle it.
- **The snake** animates only while the bar is visible, so the hidden bar costs under 1% CPU.
- **Hot reload:** the bar runs as `qs -c rice` (started by niri), and Quickshell live-reloads its QML from `~/.config/quickshell/rice`.

## Lock, idle and login

| When | What happens |
| --- | --- |
| 5 min idle | Lock (`rice-lock`) |
| 10 min idle | Screens off |
| Before sleep | Lock |

**If the lock ever breaks:** niri keeps the session locked even if the locker dies. Switch to a TTY (`Ctrl+Alt+F3`), log in and run `loginctl unlock-sessions` as root.

**If the login screen breaks:** from a TTY, `sudo nixos-rebuild switch --rollback`.

## Terminal

- **foot** reads its colours from matugen and opens floating with rounded corners. The wallpaper shows through it.
- **fastfetch** runs only in the first terminal of a session. Type `ff` to show it again.
- **starship** uses a two-line prompt, also matugen-coloured.

## Rebuild and test

```sh
nh os switch                                  # rebuild and switch
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link   # build check, no sudo
for t in tests/*-test.sh; do bash "$t"; done  # script tests (rice-wall, rice-menu, rice-lock, first-fetch)
niri validate -c ~/.config/niri/config.kdl    # niri config check
```

The flake only sees git-tracked files, so `git add` new files before building.

## Performance

These were measured after 6 minutes idle (RSS):

| Process | Memory |
| --- | --- |
| quickshell (bar) | 191 MB |
| awww-daemon | 29 MB |
| swayidle | 3.4 MB |
| **Total** | **223 MB** |

## File map

```
modules/
  desktop.nix        NixOS: rice packages, lock PAM service
  home.nix           Home Manager entry, imports the folders below
  niri/              KDL split by block (input, layout, binds, rules, misc) + generated colors.kdl
  theme/             rice-wall, matugen config and templates, wallpaper list, 45-min timer
  terminal/          foot, fastfetch, first-terminal fish hook
  rofi/              theme + rice-menu
  shell/             Quickshell: TopPill, BottomBar, snake, OSD, notifications, wallpaper picker
  lock/              Quickshell lock + rice-lock + swayidle
  sddm/              login theme (Qt6, video)
tests/               bash tests with stubbed commands (tests/lib.sh)
docs/superpowers/    design specs and implementation plans
```

## Roadmap

These are designed and planned, not built yet. Each has a spec in `docs/superpowers/specs/` and a plan in `docs/superpowers/plans/`.

1. **Cleanup:** a polkit agent, a declared cursor/icon/GTK theme, GTK colours that follow the wallpaper, and leftover removal.
2. **The python:** the cobra becomes a reticulated python that spirals around the bottom bar, three coils in front of and behind it, breathing and watching the pointer. A matching coiled python becomes the fastfetch logo.
3. **The Umbriel desktop:** a second session you pick at login, on the Umbriel compositor. It's dark, quiet and slate-grey:
   - chain-link workspaces
   - a morphing island for the clock, music, notifications and OSD
   - a launcher that drops from the island with a horned viper coiled around it
   - live hydrangea-rain and storm wallpapers
   - film grain and smoke window animations
   - a spider and a pair of eyes that you'll rarely catch
