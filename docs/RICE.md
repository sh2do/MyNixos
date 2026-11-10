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
| Menus | glassy rofi menus with static water drips: a launcher with a wallpaper image panel, plus wifi, bluetooth, audio, power-profile (with fan boost), power and clipboard menus | `modules/rofi/` |
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
| `Mod+Alt+V` | Clipboard history on a slab of pond glass, like the wallpaper picker (`ClipPicker.qml`, `rice-clip`): type to search, image entries as thumbnails; Enter pastes, Shift+Enter only copies, Delete removes the entry, Tab switches to emoji. Falls back to `rice-menu clipboard` if the shell is down; Umbriel keeps the rofi menu |
| `Mod+Alt+Period` | The same panel's emoji tab: a searchable grid of Unicode's own list (nixpkgs `unicode-emoji`), with a row of group jumps; Enter copies the emoji and types it with wtype. Mod+Period stays niri's expel-from-column. Loaded only while open, nothing animates once it has slid in |
| `Mod+Shift+Q` | Power menu |
| `Mod+Alt+W` | Next wallpaper |
| `Mod+Alt+F` | Focus mode on / off (`rice-focus`; Umbriel too) |
| `Mod+Ctrl+W` | Wallpaper picker: a carousel that slides up on a slab of pond glass, each card on a faint stone; the selected card rises with a glowing rim and the menus' drips along its bottom edge (plain beads until rice-wall has rendered them). It moves on its own clock under 60 Hz, only while the selection moves, and costs nothing closed |
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
- **The koi** swim inside the bottom bar, under the widgets: a white koi with red patches, one in the wallpaper's own colour, and a gold one. Each has shaded flanks, patches, a dorsal ridge, whiskers and paddling fins, and casts a shadow on the pond floor. They cruise and rest, and now and then rise to the surface with a ring and a few bubbles. The water has drifting caustic light, rain dimpling the surface, a lily pad they swim under, and a wake behind a darting koi. Hold the pointer still and they come up to it; move it fast near one and it darts off. Click open water and they rush to it and nibble. Switching workspace or changing volume or brightness sends a ripple that startles the koi nearby, and the closest comes back to look. While music plays they gather in the middle under the top pill and swim livelier: a bass beat (from the pill's shared cava) flicks one koi's tail with a ring above it, at most twice a second, the caustic light brightens with the loudness, and a new track brings the koi nearest the middle up with a few bubbles (`RICE_FAKE_BEAT=1` (or `RICE_KOI_FAKE_BEAT=1`) fakes a beat to see it without a player). They only swim while the bar is up. 
- **Night shift** (21:00-06:00, the raven's clock in `raven-mood.js`): over about two minutes the shell's colours (`Theme.qml`) dim about 12% and cool toward the dim surface, text only a little so it keeps its contrast, and the koi slow to a drift and gather under the lily pad, resting more and rising less (music still stirs them a little). `RICE_NIGHT=1` forces night, `RICE_NIGHT=0` day.
- **Weather** (`modules/weather`, `Weather.qml`, `weather.js`): `rice-weather` asks Open-Meteo (no key) for the current weather every 20 minutes (a user timer, in both sessions) and keeps it in `~/.cache/rice/weather.json`; `rice-weather` by hand fetches now. The place is `RICE_WEATHER_LAT` / `RICE_WEATHER_LON` in the user manager's environment, Nairobi by default. When it rains, drops ring the koi pond, more the harder it rains; fog lays a soft veil over it and dims the caustics. On a clear or cloudy day the pond is unchanged. Changes ease in over about 10 s. Offline, the last reading stays; once it's 3 h old both shells go back to their own scenes. `RICE_WEATHER=storm` (or clear, cloudy, fog, drizzle, rain, snow) in the shell's environment forces a kind.
- **Seasons** (`season.js`, `Season.qml`, with the raven's files in `modules/umbriel/shell`, shared by both shells): a light touch by the month. In spring (March-May) a few petals drift down onto the koi pond and settle on the water with a small ring; on summer nights a few fireflies hover over it; in October a pumpkin and a candle stand on the rim ahead of the bar raven (and float on the lily pad when the koi are out); in December sparse snow falls into the pond and melts in a ring. On Umbriel the petals, fireflies and snow drift down the right of the desktop, under the island to the raven's corner, behind every window, and the pumpkin and candle sit at the end of the raven's hoard. Real rain or a storm clears the petals, snow and fireflies, and focus mode pauses them (the candle holds still). The sprites ride the koi's tick (Umbriel: a 15 Hz timer in a window that exists only during a season and stops while hidden, covered or locked); outside a season nothing extra runs. `RICE_SEASON=spring` (summer, october, december, none) forces one.
- **Sounds** (`modules/shell/sounds.nix`, `Sound.qml`, `sound.js`): both shells play a soft water drop for a notification and a low caw for a critical one; the niri OSD plays a ripple tick for volume steps (at most one per 150 ms). They are made with sox at build time and played by `pw-play` for a moment each, so nothing runs while idle. They stay silent at night (21:00-06:00) and while the default sink is muted. `RICE_SOUNDS=0` in the session environment turns them off.
- **The raven** (set `RICE_MASCOT=raven` in the session environment to get it instead of the koi; there is no python any more) perches on the bottom bar's top rim at its right end, about 44 px tall. It is Umbriel's raven (the same art, `RavenBody.qml`, and moods, `raven-mood.js`, copied in from `modules/umbriel/shell`), coloured from the wallpaper: a very dark body, feathers edged in a dark slate of the outline colour, and a faint sheen of the primary and tertiary colours, deepened, so it reads black rather than grey. It breathes, blinks, looks about, now and then ruffles its feathers and preens. A pointer resting on the bar is watched after 2 s, then hopped at and pecked at. Switching workspace or changing volume or brightness makes it turn its head to the change and caw (two silent arcs from the beak); the values arriving at startup don't. After dark (21:00-06:00) it sleeps with its head tucked in; a change on the bar wakes it for a while. While a player plays it bobs its head (about 120 ms, down a few px with a small forward tilt) to each bass beat of the shared cava, at most twice a second, unless it is asleep, preening, hopping or cawing (`RICE_FAKE_BEAT=1` fakes the beat). `RICE_RAVEN_DEBUG=1` makes it ruffle and preen every 20 s, and makes it night for 30 s of every 2 minutes.
- Either one animates only while the bar is visible: about 0.3% CPU hidden. The koi tick at 48 Hz; the raven's clock ticks at 5 Hz at rest, 30 Hz while its head moves and 60 Hz in a hop or a caw. Shown, the koi cost about 6% of a core and the raven about 1% when measured on their own (15% and 3.4% with a near-invisible measuring window, in the same session before and after the glass change, so no measurable change). Hidden, either is 0.3% or less. Ripples and bubbles run on the koi's 48 Hz clock rather than animations, which would redraw at the display's full rate.
- **Hot reload:** the bar runs as `qs -c rice` (started by niri). `nh os switch` restarts it when its QML changed, because a running bar keeps watching the old store path.

## Notifications and OSD

- **Cards:** one card per app, newest first, at most 4 on screen. A new message from the same app updates its card in place. A card shows the app icon, "app · count" and its age, the latest message with a 36 px avatar, and the app's own action buttons (such as Reply). Older messages peek out under it as stack edges; the chevron opens them. Clicking a card runs the latest message's default action and dismisses the group. After 5 s the card expires (a thin line runs down); a new message restarts it. Critical cards have an error-coloured border and stay until clicked.
- **Water OSD:** the volume and brightness keys show a 56 x 168 glass capsule at the bottom centre, filled with water to the level. Each change sends ripples across the surface, and a held key makes a steady train. It hides after 1.5 s. It redraws at 20 Hz for 500 ms after a change, then 6 Hz for the slow drift.
- **Focus mode** (`rice-focus [on|off|toggle|status]`, `Mod+Alt+F` on both desktops, the moon chip in the bar's toggles, or the phone's "Focus" button; `Focus.qml`, `focus.js`, shared by both shells): it writes `~/.cache/rice/focus`, which both shells watch. While on, notifications are held, with no card and no sound; critical ones still show with the caw, and still go to the phone. When it ends, one card says "N held while you focused", with a line per app, until clicked (on Umbriel, one island notice: "Discord 2 · Mail 1"). The raven sleeps, the koi drift as at night and ignore the music, and Umbriel's viper hangs still and stops dripping (its clock stops). The bar's chip shows "focus 25m", and Umbriel's status corner shows the same, stepped once a minute. Nothing else runs while it is on. A game in gamemode calms the desktop the same way (see Gaming).
- Cost: about 3% of a core while a card's timeout line runs, 0 with only critical cards; the OSD is about 1.4-2.8% while visible.

## Phone link

The phone talks to the desktop over KDE Connect (an open protocol on the LAN, no cloud). `programs.kdeconnect` in `configuration.nix` installs it and opens TCP and UDP 1714-1764 in the firewall; niri (`config.kdl`) and Umbriel (its autostart) start `kdeconnectd` at login.

- **Phone to desktop:** the phone's notifications arrive as ordinary desktop notifications: grouped cards on niri, the island on Umbriel.
- **The chip:** on niri's bottom bar, after the clock: a phone icon, the phone's battery ("87%", "87%+" while charging) and the 3 px "on" dot while it is reachable; a crossed-out phone and no battery while it is away. **Click** rings the phone (find my phone). **Right-click** opens a zenity file picker and sends the file. It is hidden while no phone is paired. Umbriel shows the same as a faint glyph and battery at the left of its status corner.
- **How it's read:** `Phone.qml` (shared by both shells; Umbriel copies it in) asks the daemon over D-Bus with a few `busctl` calls every 30 s: the paired devices, then each one's `isReachable`, `name` and the battery plugin's `charge` and `isCharging`. `phone.js` parses that and picks the phone (the first reachable one, else the first paired). No daemon or nothing paired: no phone, nothing shown.
- **`phone-alert "<message>"`** shows the message on the first paired phone that is reachable (`kdeconnect-cli --ping-msg`), e.g. `nh os switch; phone-alert "switch done"`. `phone-alert --critical "<message>"` prefixes it with "Critical: ". With no phone reachable it says so and exits 1; a missing message exits 2.
- **Critical forwarding:** every **critical** desktop notification is also sent to the phone (`phone-alert --critical "summary: body"`); ordinary ones are not. Notifications that came from the phone (app "KDE Connect") are never sent back. `RICE_PHONE_FORWARD=off` in the session environment switches it off; `critical` is the default.

**Pairing (once, by hand):**

1. Install **KDE Connect** on the phone (F-Droid or Play Store; iOS support is limited) and open it.
2. Put the phone on the same Wi-Fi as this machine.
3. Pair: on the phone, tap this machine in KDE Connect's list and "Request pairing", then accept the request on the desktop (`kdeconnect-app`, or `kdeconnect-cli --list-devices` for its id and `kdeconnect-cli --pair -d <id>`). Or start it from the desktop: `kdeconnect-cli --refresh; kdeconnect-cli --list-devices`, then `kdeconnect-cli --pair -d <id>` and accept on the phone.
4. Test: `phone-alert "hello"` pops up on the phone. On the phone, allow KDE Connect's notification access ("Send notifications") so phone notifications reach the desktop.
5. Phone buttons: the KDE Connect app's "Run command" lists lock, play/pause, next/previous, volume, mute, next wallpaper, focus, screenshot to phone, sleep and shut down. Every switch sets them; after pairing a new phone, run `phone-commands`. Edit the list in `modules/shell/phone-commands.sh`, not in the app.

Checks after switching and pairing:

- [ ] `busctl --user list | grep kdeconnect` shows `org.kde.kdeconnect` in both sessions.
- [ ] The bar's phone chip shows the battery and the dot; turn the phone's Wi-Fi off and within 30 s it shows the crossed-out phone; unpair (`kdeconnect-cli --unpair -d <id>`) and the chip goes.
- [ ] Clicking the chip rings the phone; right-clicking sends a file.
- [ ] `notify-send -u critical -a test "Disk full" "3% left"` reaches the phone as "Critical: Disk full: 3% left"; a plain `notify-send hi` does not.
- [ ] A phone notification shows as a desktop card and does not come back to the phone.

## Lock, idle and login

| When | What happens |
| --- | --- |
| 5 min idle | Lock (`rice-lock`) |
| 10 min idle | Screens off |
| Before sleep | Lock |

**Lock extras:** small pond-glass pills low on the lock screen, each shown only when it has something: now playing (art, title, artist, and previous / play-pause / next, nothing more), the paired phone's battery, and the weather. They share `media.js`, `phone.js`, `weather.js`, `Phone.qml` and `Weather.qml` with the shell (copied in by `modules/lock/default.nix`). `RICE_LOCK_PREVIEW=1 qs -c rice-lock` shows the screen in a normal window without locking.

**If the lock ever breaks:** niri keeps the session locked even if the locker dies. Switch to a TTY (`Ctrl+Alt+F3`), log in and run `loginctl unlock-sessions` as root.

**If the login screen breaks:** from a TTY, `sudo nixos-rebuild switch --rollback`, or reboot and pick the previous generation in the systemd-boot menu.

## Terminal

- **foot** reads its colours from matugen and opens floating with rounded corners. The wallpaper shows through it.
- **fastfetch** runs only in the first terminal of a session. Type `ff` to show it again.
- **starship** uses a two-line prompt, also matugen-coloured.

## App colours

matugen also colours apps outside the shell (templates in `modules/theme/templates`):

- **Qt 5 and 6** (Kate, kdeconnect-app, Dolphin if installed): `QT_QPA_PLATFORMTHEME=qt5ct` is set for every session (`configuration.nix`), qt5ct and qt6ct use Fusion with matugen's palette (`~/.config/qt{5,6}ct/colors/rice.conf`), and KDE apps also read the scheme from `~/.config/kdeglobals`, which matugen rewrites on each wallpaper change. Running Qt apps keep the old palette until restarted.
- **Firefox**: matugen writes `userChrome.css` and `userContent.css` to `~/.cache/rice/firefox/`, and `rice-wall` copies them into `chrome/` of every profile in `profiles.ini` (under `~/.config/mozilla/firefox` or `~/.mozilla/firefox`). Only the toolbar, tabs, urlbar and panels change, plus a faint glass rim on the urlbar and the open tab; websites keep their look (`userContent.css` touches only the new tab and blank pages). A `userChrome.css` that rice-wall didn't write is left alone. The policy `toolkit.legacyUserProfileCustomizations.stylesheets` turns loading on. **Restart Firefox** to see new colours.
- **Discord** is the official client with Vencord (`discord.override { withVencord = true; }`). Vencord is a client mod, against Discord's terms in theory. matugen writes `~/.config/Vencord/themes/rice.css`, which Vencord reloads live; `rice-wall` turns it on once in Vencord's settings, so switching it off in Settings → Vencord → Themes sticks.
- **kitty** outside Umbriel reads `~/.config/kitty/colors.conf` and reloads on each wallpaper change. Umbriel's kitty keeps its slate palette.
- Spotify is installed but not themed (that would need spicetify).

Checks after switching (the switch regenerates the colours once, since the templates changed):

- [ ] `echo $QT_QPA_PLATFORMTHEME` says `qt5ct` in a new login, and `kate` or `kdeconnect-app` uses the wallpaper's colours.
- [ ] Quit and reopen Firefox: the toolbar and tabs match the wallpaper. If not, check `about:config` → `toolkit.legacyUserProfileCustomizations.stylesheets` is true and the profile's `chrome/` has both files.
- [ ] Quit Discord fully and reopen it: Settings shows a Vencord section, and Themes has **Rice** ticked (tick it if not).
- [ ] `rice-wall next`: Discord and kitty change colour without a restart.

## Backups

`rice-backup` (`modules/backup/`) backs up `$HOME` with restic. Nothing runs until a destination is chosen: plug in a USB drive and run `rice-backup init /run/media/Zaion/<label>/restic`, or for off-site use a Backblaze B2 bucket (`B2_ACCOUNT_ID` / `B2_ACCOUNT_KEY` in `~/.config/rice-backup/env`, mode 600, then `rice-backup init b2:<bucket>:laptop`). Any restic repository string works (`sftp:host:/path`, `rclone:remote:path` with rclone installed).

- **init** saves the repository in `~/.config/rice-backup/repo` and generates `~/.config/rice-backup/password` (mode 600) if missing. **Keep a copy of the password off this machine**: a lost laptop takes the only copy with it. A repository the password already opens is adopted, not re-created; a failed init saves nothing.
- **now** backs up `$HOME` (one file system, tag `rice-backup`), then `forget --prune` keeping 7 daily, 4 weekly and 6 monthly. Excluded: `~/.cache`, CACHEDIR.TAG folders, `~/.local/share/Steam`, `~/.steam`, the Trash, containers, `node_modules`, `.direnv`, nix `result*` links, VM images (`*.qcow2`, `*.vdi`, `*.vmdk`, `*.vhd*`, libvirt and Boxes images), `~/Downloads/*.iso`, `~/restore` and a repository inside `$HOME`. Two runs never overlap.
- **status** shows the repository, the last success and the last snapshot with its age.
- **restore `<path>` [snapshot]** restores the path (default: the latest snapshot) into `~/restore/<date>/<full path>`, never in place.
- **Timer:** `rice-backup.timer`, daily with up to an hour's random delay, `Persistent` (a day missed while off or asleep runs soon after boot), `Nice=19` and idle CPU and IO scheduling; on battery the day's run is skipped (`ConditionACPower`). `journalctl --user -u rice-backup` has the log.
- **When it can't:** not set up, or a local repository whose drive is unplugged: it says so and exits 0. Once the last success is over 7 days old (or 7 days pass after init with none), it warns with `phone-alert` and `notify-send`, at most once a day. A failed backup or prune sends a critical `phone-alert` and desktop notification. State lives in `~/.local/state/rice-backup`.

Checks after switching:

- [ ] `systemctl --user list-timers rice-backup` shows the timer; `rice-backup status` says it is not set up.
- [ ] After `rice-backup init <repo>` and `rice-backup now`, `rice-backup status` shows a snapshot from just now, and `rice-backup restore ~/.bashrc` (or any file) puts a copy under `~/restore/<date>/`.

## Power and fans

`modules/power/` plus the NVIDIA block in `configuration.nix`. This is what the OMEN 16-an0xxx (board 8D40) lets Linux control:

| What | Where | Controllable |
| --- | --- | --- |
| Power profiles | power-profiles-daemon | yes, but only the CPU (intel_pstate's energy preference). The patched hp-wmi has no thermal profile for board 8D40, so there is no `platform_profile` and the firmware's own fan curve and power limits don't change with the profile |
| Fans | hp-wmi hwmon (`name` = `hp`): `pwm1_enable`, `fan1_input`/`fan2_input` (CPU/GPU, about 6000 and 5800 rpm max) | yes: max (0), manual (1), auto (2). The driver keeps max mode alive on its own |
| dGPU power | NVIDIA runtime D3 | yes, with fine-grained power management (below) |
| Charge limit | `BAT0` | no: HP has no charge thresholds on Linux (see the battery note below) |
| GPU mux | hp-wmi `gpu_mux_mode` | readable (0 = hybrid); not touched here |

- **Auto profile** (`rice-power-auto`, a system service): pulling the charger switches to power-saver; plugging it back in returns to the profile you had on AC. udev starts it when a charger comes or goes (ADP1 or a USB-C charger), and it also runs at boot and after resume for a charger that changed while the laptop was off or asleep. It only acts on a real change, so a profile you pick by hand stays. If you pick another profile on battery, plugging in keeps your pick. While a game runs (gamemode's `rice-game-power`, `modules/gaming`) or something holds a profile (`powerprofilesctl launch`), it changes nothing, and the profile the game replaced is remembered as the AC profile. State lives in `/var/lib/rice-power`, and `journalctl -u rice-power-auto` has the log. Known gap: if you plug in during a game started on battery, the game puts power-saver back when it ends; pick the profile again.
- **Fan boost** (`rice-fan max | auto | toggle | status`): holds both fans at max until `rice-fan auto` or a reboot. A udev rule gives the wheel group write access to `pwm1_enable`, so no sudo is needed. It is also in the profile menu (`rice-menu profile`, or right click the profile glyph) as "fan boost". While boost is on, the niri bar shows a lit 󰈐 boost chip and Umbriel's corner shows 󰈐; a click on either turns it off. Both shells check every 30 s.
- **Bar:** the niri bar's profile chip is now a glyph next to the battery (󰾆 power-saver, 󰾅 balanced, 󰓅 performance, with the dot lit off balanced). Click to cycle and right click for the menu. Umbriel's corner shows the same glyph before the battery, and a click cycles it there too.
- **NVIDIA runtime D3:** `hardware.nvidia.powerManagement.finegrained = true` (PRIME offload, which it needs, is already on). It sets `NVreg_DynamicPowerManagement=0x02` and udev rules that set the dGPU's `power/control` to `auto`. Before this it was `on`, so the dGPU never slept and drew about 7 W idle at P8. `nvidiaBusId` was also corrected from `PCI:0:1:0` (the PCIe bridge) to `PCI:1:0:0`; that only matters to an Xorg session. The lock screen's video now decodes on the Intel GPU (`QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi`), so locking doesn't wake the dGPU. niri still opens the dGPU because the HDMI port (and the muxed panel output `eDP-2`) are wired to it. With fine-grained mode an idle dGPU can still suspend while it's open; if it never does, see the checks.
- **Battery note:** HP firmware has no charge limit that Linux can set (`BAT0` has no `charge_control_*` files). The BIOS has one: **Adaptive Battery Optimizer** (press F10 at power-on to open BIOS setup; it is usually under Configuration, set it to Enabled). It watches how the laptop is used, and when it is kept plugged in most of the time it stops the battery sitting at a full charge, which slows wear. Turn it on if the laptop lives on the charger. Linux sees the effect only as a battery that stops short of 100%.

Checks after switching and **rebooting** (the NVIDIA module option and the udev rules need a fresh boot):

- [ ] `cat /sys/bus/pci/devices/0000:01:00.0/power/control` says `auto`. After a minute idle with nothing on the dGPU, `cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status` says `suspended`, and `/proc/driver/nvidia/gpus/0000:01:00.0/power` shows "Runtime D3 status: Enabled (fine-grained)". (Don't use `nvidia-smi` to check: it wakes the GPU.) If it stays `active`, look for what has `/dev/nvidia0` open. niri drives HDMI from it. niri's debug option for ignoring a DRM device would free the dGPU, but HDMI would stop working.
- [ ] A Steam game (or `nvidia-offload <app>`) still runs on the NVIDIA GPU, and the dGPU suspends again a little after it closes.
- [ ] Unplug: `powerprofilesctl get` says `power-saver` within a second and the bar glyph changes. Plug in: back to what it was. Set performance by hand on battery and plug in: it stays performance.
- [ ] `ls -l /sys/class/hwmon/*/pwm1_enable` shows group `wheel`, mode `rw-rw-r--`. `rice-fan max`: the fans spin up within a few seconds, the bar shows the boost chip, and `rice-fan` reports about 5800 rpm. `rice-fan auto` (or a click on the chip) brings them back down.

## Gaming

`modules/gaming/` (NixOS) holds Steam, gamemode, MangoHud and gamescope; the NVIDIA driver and PRIME offload stay with the graphics in `configuration.nix`.

- **Which GPU:** PRIME offload, so the desktop and every app run on the Intel GPU and the NVIDIA one sleeps (runtime D3, under "Power and fans"). Steam starts with `MESA_VK_DEVICE_SELECT=discrete` and `MESA_VK_DEVICE_SELECT_FORCE_DEFAULT_DEVICE=1`, and every game inherits them: Vulkan, which means all Proton games (DXVK, VKD3D) and native Vulkan games, sees only the NVIDIA GPU. OpenGL is not switched, so Steam's own window stays on the iGPU and doesn't keep the dGPU awake while Steam idles in the tray. A native OpenGL game needs `nvidia-offload` in front (below). Outside Steam: `nvidia-offload <app>`.
- **Launch options** (Steam: right click a game, Properties, Launch options). Steam has no global launch options, so set this per game:

  ```
  gamemoderun mangohud %command%
  ```

  For a native OpenGL game: `nvidia-offload gamemoderun mangohud %command%`. Setting gamemode or MangoHud in Steam's own environment instead would apply them to Steam itself, keeping the performance profile on whenever Steam is open.
- **gamemode** (`/etc/gamemode.ini`): the game runs at nice -10 and the screensaver is inhibited. On start `rice-game-power start` notes the power profile and asks power-profiles-daemon for `performance`; on end `rice-game-power end` puts the noted one back, unless the profile was changed away from performance during the game (by you, or by `rice-power-auto`), in which case that choice stands. It only uses `powerprofilesctl`; gamemode's own CPU governor switch is set to intel_pstate's normal `powersave`, which leaves the governor as it is. The note is `$XDG_RUNTIME_DIR/rice-game/profile`, which `rice-power-auto` reads to keep its hands off while a game runs. `gamemoded -s` says whether it is active.
- **MangoHud:** a small overlay at the top left: FPS, frame time and its graph, CPU and GPU load and temperature, VRAM. **Shift+F12** (left Shift) shows and hides it. Its colours come from the wallpaper: matugen writes `~/.config/MangoHud/MangoHud.conf` from `modules/theme/templates/MangoHud.conf`, and MangoHud rereads it while a game runs.
- **The desktop goes calm** while gamemode has a game (`Game.qml`, `game.js`, shared by both shells): the same as focus mode (`Focus.qml`'s `calm`), without touching `rice-focus`. Notifications are held (critical ones still show), and when the game ends one card says "N held while you played". The raven sleeps, the koi drift, Umbriel's viper hangs still and the season's sprites stop. A 󰊗 "game" chip shows in the niri bar, right of the clock, and in Umbriel's status corner. The shells check every 10 s: one `busctl` call asking whether gamemoded is on the session bus (which never starts it), and the client count only if it is.
- **gamescope** (optional): a nested compositor for a fixed resolution or frame cap. Launch options: `gamescope -W 1920 -H 1200 -r 144 -f --mangoapp -- gamemoderun %command%` (`--mangoapp` replaces `mangohud` inside gamescope). Not tried on this hybrid GPU setup; if it shows a black window, leave it out.

Checks after switching:

- [ ] A Proton game with `gamemoderun mangohud %command%`: MangoHud shows the NVIDIA GPU (its name in the GPU line, or `nvidia-smi` lists the game), in the wallpaper's colours. Shift+F12 hides and shows it.
- [ ] While it runs: `gamemoded -s` says active, `powerprofilesctl get` says `performance`, the bar (or Umbriel's corner) shows the game chip within 10 s, the koi drift (or the raven sleeps), and a `notify-send hi` shows no card. After quitting: the profile is back to what it was, the chip goes, and one card says "1 held while you played".
- [ ] With Steam open and no game running, the dGPU still suspends (`cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status` says `suspended` after a minute).

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

Boot splash and login (`modules/boot`, `modules/sddm`), on the next reboot:

- [ ] The systemd-boot menu still shows for 5 s and lists the older generations.
- [ ] The boot is quiet: no scrolling messages, then the **rice-pond** splash: a dark pond, two koi circling slowly, the raven perched on the rim at the upper right. Esc shows the boot messages; Esc again hides them.
- [ ] Shutdown and reboot show the same splash.
- [ ] The login: the train video plays behind a card of pond glass (frosted, lit top rim, water along the bottom, drops hanging under it). The avatar sits on the card's top edge.
- [ ] Log in with the password and get the chosen session. Try a wrong password once: it shakes and says "wrong password". Left/Right (or a click) cycles niri and Umbriel. The power buttons at the bottom right suspend, reboot and power off.

**If the login or boot breaks:** reboot, pick the previous generation in the systemd-boot menu (the one before this switch), then `sudo nixos-rebuild switch --rollback` or fix and switch again. If SDDM can't load the theme it falls back to its plain greeter, so the login still works. To boot without the splash once, press `e` on the entry and delete `quiet splash`.

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
python3 modules/boot/make-plymouth-art.py                # regenerate the boot splash art
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
  theme/             rice-wall, matugen config and templates (incl. glass colours, the menu drips and app colours: Qt, Firefox, Vencord, kitty), wallpaper list, 45-min timer
  terminal/          foot, kitty (outside Umbriel), fastfetch, first-terminal fish hook
  rofi/              glass theme + rice-menu
  shell/             Quickshell: TopPill (+ media.js), BottomBar, Koi (+ koi-motion.js), Raven (art and moods from umbriel/shell), Osd, Notifications (+ notify-group.js), wallpaper picker, clipboard and emoji panel (ClipPicker + clip.js, emoji.js, rice-clip)
  lock/              Quickshell lock + rice-lock + swayidle
  sddm/              login theme (Qt6, video)
  look/              polkit agent, cursor, icon, GTK and qt5ct/qt6ct themes (colours come from matugen)
  backup/            rice-backup (restic) and its daily timer
  power/             NixOS: rice-power-auto (profile follows the charger), rice-fan (fan boost) and their udev rules
  gaming/            NixOS: Steam (Vulkan on the dGPU), gamemode with rice-game-power, gamescope, MangoHud
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
