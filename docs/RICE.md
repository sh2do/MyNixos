# The Rice

A from-scratch niri desktop on NixOS: rotating rainy wallpapers that recolour the whole desktop, a Quickshell bar with koi swimming under its glass, rofi menus, a floating foot terminal, and video lock and login screens. Everything is declared in this repo and deployed by Home Manager. Nothing is hand-edited in `~/.config`.

> Branch `niri-rice`. Designs and plans live in `docs/superpowers/` (see [Roadmap](#roadmap)).

---

## At a glance

| Piece | What you see | Where it lives |
| --- | --- | --- |
| Compositor | niri 26.04, scrolling columns, rounded floating terminals, eased open/close animations | `modules/niri/` |
| Wallpapers and colours | a curated rainy/purple rotation that changes every 45 min, with a fade; every colour in the desktop follows it | `modules/theme/` |
| Bar | a top pill (a living media pill while music plays, otherwise the focused window title) and an auto-hide pond-glass bottom bar (workspaces, toggles, clock, power), with koi or a raven in it | `modules/shell/` |
| Menus | glassy rofi menus with static water drips: a launcher with a wallpaper image panel, plus wifi, bluetooth, audio, power-profile, power and clipboard menus | `modules/rofi/` |
| Terminal | foot, starship two-line prompt, fastfetch (a koi pond logo) only in the first terminal | `modules/terminal/` |
| OSD and notifications | a water-capsule volume and brightness OSD, and notification cards grouped by app (critical ones stay) | `modules/shell/` |
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
 niri colors  rofi colors   foot colors  starship    colors.json   koi logo
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

- **Glass:** the window is translucent (the matugen surface colour at 70% alpha) with a light edge, a specular rim along the top and raised-glass input bar. niri blurs what is behind it through a layer-rule on the `rofi` namespace in `modules/niri/rules.kdl` (`background-effect { blur true }`, rounded to 16 px). The blur is the wallpaper only (xray), so it is cheap.
- **Drips:** water has run down the glass and gathered along the bottom of the list: runs ending in beads, lone beads and a thin film. The selected row is a primary pill with one drop hanging from its lower edge. Both are static images (`drips.svg` and `drip-row.svg`, matugen templates rendered to `~/.cache/rice/*.png` by rsvg-convert), so they cost nothing.
- **The drips appear after the next recolour** (`rice-wall next`, a pick, or the 45 min timer). Until then the menus look as before, with a plain pill. `rice-wall set "$(rice-wall current)"` makes them appear at once.
- In Umbriel the same menus get no blur, only the 70% glass.

## Bar

- **Top pill:** the focused window's title, or, while music plays, a living media pill. It stays tucked above the screen edge and drops in for a few seconds when a song starts or changes, or when you switch workspace; the pointer over it keeps it down. Fullscreen windows hide it.
  - **The media pill:** 40 px tall, 300-480 px wide. It shows 28 px album art with a soft glow behind the pill in the art's colour (from local art; otherwise the wallpaper's primary), the title in bold and "artist · album" under it, five bars that dance to the music (from `cava`, with a gentle fallback if it can't run) and a thin progress line with a playhead along the bottom. Hover swaps the text and bars for previous, play/pause and next.
  - Cost: about 2% of a core, plus about 0.6% for `cava`, only while the pill is down. Tucked away it is 0% and `cava` isn't running.
- **Bottom bar:** a 42 px slab of pond glass: a lit top rim, a faint depth gradient and reflection band, and the widgets on three faint stones (workspaces, toggles, clock). The active workspace is a glowing capsule; a toggle that is on has a lit icon and a 3 px dot under it. It auto-hides, leaving a faint 120 × 2 px water line centred at the screen edge. Touch the edge to slide it up. Its decorations are static, so they cost nothing at rest. `RICE_BAR_PINNED=1 qs -c rice` keeps it up while you restyle it.
- **The koi** swim inside the bottom bar, under the widgets: a white koi with red patches, one in the wallpaper's own colour, and a gold one. Each has shaded flanks, patches, a dorsal ridge, whiskers and paddling fins, and casts a shadow on the pond floor. They cruise and rest, and now and then rise to the surface with a ring and a few bubbles. The water has drifting caustic light, rain dimpling the surface, a lily pad they swim under, and a wake behind a darting koi. Hold the pointer still and they come up to it; move it fast near one and it darts off. Click open water and they rush to it and nibble. Switching workspace or changing volume or brightness sends a ripple that startles the koi nearby, and the closest comes back to look. While music plays they gather in the middle under the top pill and swim livelier: a bass beat (from the pill's shared cava) flicks one koi's tail with a ring above it, at most twice a second, the caustic light brightens with the loudness, and a new track brings the koi nearest the middle up with a few bubbles (`RICE_KOI_FAKE_BEAT=1` fakes a beat to see it without a player). They only swim while the bar is up. 
- **The raven** (set `RICE_MASCOT=raven` in the session environment to get it instead of the koi; there is no python any more) perches on the bottom bar's top rim at its right end, about 44 px tall. It is Umbriel's raven (the same art, `RavenBody.qml`, and moods, `raven-mood.js`, copied in from `modules/umbriel/shell`), coloured from the wallpaper: a very dark body, feathers edged in a dark slate of the outline colour, and a faint sheen of the primary and tertiary colours, deepened, so it reads black rather than grey. It breathes, blinks, looks about, now and then ruffles its feathers and preens. A pointer resting on the bar is watched after 2 s, then hopped at and pecked at. Switching workspace or changing volume or brightness makes it turn its head to the change and caw (two silent arcs from the beak); the values arriving at startup don't. After dark (21:00-06:00) it sleeps with its head tucked in; a change on the bar wakes it for a while. `RICE_RAVEN_DEBUG=1` makes it ruffle and preen every 20 s, and makes it night for 30 s of every 2 minutes.
- Either one animates only while the bar is visible: about 0.3% CPU hidden. The koi tick at 48 Hz; the raven's clock ticks at 5 Hz at rest, 30 Hz while its head moves and 60 Hz in a hop or a caw. Shown, the koi cost about 6% of a core and the raven about 1% when measured on their own (15% and 3.4% with a near-invisible measuring window, in the same session before and after the glass change, so no measurable change). Hidden, either is 0.3% or less. Ripples and bubbles run on the koi's 48 Hz clock rather than animations, which would redraw at the display's full rate.
- **Hot reload:** the bar runs as `qs -c rice` (started by niri). `nh os switch` restarts it when its QML changed, because a running bar keeps watching the old store path.

## Notifications and OSD

- **Cards:** one card per app, newest first, at most 4 on screen. A new message from the same app updates its card in place. A card shows the app icon, "app · count" and its age, the latest message with a 36 px avatar, and the app's own action buttons (such as Reply). Older messages peek out under it as stack edges; the chevron opens them. Clicking a card runs the latest message's default action and dismisses the group. After 5 s the card expires (a thin line runs down); a new message restarts it. Critical cards have an error-coloured border and stay until clicked.
- **Water OSD:** the volume and brightness keys show a 56 x 168 glass capsule at the bottom centre, filled with water to the level. Each change sends ripples across the surface, and a held key makes a steady train. It hides after 1.5 s. It redraws at 20 Hz for 500 ms after a change, then 6 Hz for the slow drift.
- Cost: about 3% of a core while a card's timeout line runs, 0 with only critical cards; the OSD is about 1.4-2.8% while visible.

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

## After switching

Checks for the niri side, once, after `nh os switch` restarts `qs -c rice` and loads the new niri config.

- [ ] `rice-wall set "$(rice-wall current)"` once, so the menu drips appear. Then `rice-menu apps`: glass, drips along the bottom, a drop under the selected row, and the wallpaper **blurred behind it** (the blur layer-rule is only validated, not yet seen live).
- [ ] `notify-send -a test -A reply=Reply hi` three times, then `notify-send -a other hi2`: one "test · 3" card with stack edges, the chevron and a working Reply button, and a separate "other" card.
- [ ] `notify-send -u critical -a power "Battery low" "12%"` stays until you click it.
- [ ] Real actions reach the sending app (for example Discord's Reply or Mark read).
- [ ] The volume and brightness keys show the water capsule. Hold one and judge the feel at 20 Hz then 6 Hz.
- [ ] Play a song: the media pill drops in with art, a glow, dancing bars and a progress line. Hover it for the controls. Check the CPU while it is down.
- [ ] The bottom bar looks like pond glass: lit rim, stones, a glowing active workspace, and the faint water line when hidden. Touch the edge to raise it.
- [ ] `RICE_MASCOT=raven` in the session environment (then log in again) gives the raven on the rim instead of the koi: near-black with dark slate edges, no caw at login.
- [ ] `niri validate -c ~/.config/niri/config.kdl` says the config is valid.

## Rebuild and test

```sh
nh os switch                                  # rebuild and switch
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link   # build check, no sudo
for t in tests/*-test.sh; do bash "$t"; done  # script and config tests
for t in tests/*-test.js; do nix run nixpkgs#nodejs -- "$t"; done   # node tests, all of them
nix run nixpkgs#nodejs -- tests/media-test.js             # media pill: cava, progress, text
nix run nixpkgs#nodejs -- tests/notify-group-test.js      # notification grouping
nix run nixpkgs#nodejs -- tests/raven-mood-test.js        # raven moods (niri bar and Umbriel)
nix run nixpkgs#nodejs -- tests/koi-motion-test.js        # koi swimming
nix run nixpkgs#nodejs -- tests/beat-test.js              # koi beats in the bass
python3 modules/theme/make-koi-svg.py                    # regenerate the fastfetch koi logo template
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
  niri/              KDL split by block (input, layout, binds, rules incl. the rofi blur, misc) + generated colors.kdl
  theme/             rice-wall, matugen config and templates (incl. glass colours and the menu drips), wallpaper list, 45-min timer
  terminal/          foot, fastfetch, first-terminal fish hook
  rofi/              glass theme + rice-menu
  shell/             Quickshell: TopPill (+ media.js), BottomBar, Koi (+ koi-motion.js), Raven (art and moods from umbriel/shell), Osd, Notifications (+ notify-group.js), wallpaper picker
  lock/              Quickshell lock + rice-lock + swayidle
  sddm/              login theme (Qt6, video)
  look/              polkit agent, cursor, icon and GTK themes (GTK colours come from matugen)
tests/               bash tests with stubbed commands (tests/lib.sh)
docs/superpowers/    design specs and implementation plans
```

## Roadmap

Each item has a spec in `docs/superpowers/specs/` and a plan in `docs/superpowers/plans/`.

1. **The Umbriel desktop** (built; how to pick it, its keys and `umbriel-wall` are in the [README](../README.md#umbriel-desktop)): a second session you pick at login, on the Umbriel compositor. It's dark, quiet and slate-grey:
   - chain-link workspaces
   - a morphing island for the clock, music, notifications and OSD
   - a launcher that drops from the island with a horned viper coiled around it
   - live hydrangea-rain and storm wallpapers
   - film grain and smoke window animations
   - a horned viper hanging from the island, its venom dripping at a rate that follows CPU load
   - a raven on the status row that keeps a hoard of the notices' trinkets
   - a spider and a pair of eyes that you'll rarely catch
