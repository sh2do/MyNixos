# The Umbriel desktop: dark, quiet, with things hidden in it

Date: 2026-11-06
Status: approved in conversation, awaiting doc review

## Why

The user wants a **second desktop they can pick at login**, next to the niri rice. It runs on the **Umbriel** compositor (`github:noctalia-dev/umbriel`). It should feel different from the niri one: dark and understated, something that "doesn't draw too much attention unless you know what it is". It's full of small hidden details (spiders, chains, crows, eyes) that you only catch if you happen to look.

The direction went through cathedral/gothic, paintings and cathedral photos, all rejected, before settling here. Don't drift back towards ornate gothic.

## What the user decided

### Layout: no full bar ("corners + island")

- **Top-left: chain-link workspaces.** Each workspace is a small chain link drawn as an outline.
  - Empty links are dim, occupied ones are brighter, and the active one is bright with a faint glow.
  - When you switch workspace the active link swings and settles, like a real chain ("clink").
- **Top-centre: the island.** A small black pill showing only the time, which morphs with a springy animation into:
  - the playing song (title, artist, a small animated equaliser)
  - a notification (app icon or art, title, body)
  - the volume and brightness OSD
  - then it shrinks back.
- **Bottom-right: faint status.** Small, low-contrast wifi, bluetooth and battery.
- **No other bar.** Inspired by the r/unixporn post "Umbriel going topbarless (almost)", which couldn't be fetched; Reddit blocks automated access.

### Launcher

The launcher drops open **out of the island**: the island stretches down into a tall black search list, then shrinks back. It isn't a separate rofi window. *My call:* the niri desktop keeps its rofi launcher, untouched.

### The launcher's viper (user decision)

A **desert horned viper** (*Cerastes cerastes*) coils around the launcher panel while it's open. The approved mockup is `viper-launcher.html`, option B.

- **Pose:** the body winds around the panel twice, diagonally, passing in front of and behind it. The front crossings sit between list rows, never over the search field or the selected row. The head rears over the panel's top-right corner, looking down at the search field, drawn back in an S like it's about to strike.
- **Look:** a stubby, thick body; paired darker blotches; rough keeled-scale texture; a broad triangular head; and two small horns above the eyes. These are the species tells and must read clearly.
- **Colour:** the desktop's slate greys (the mockup used body `#4a4f58`, blotches `#262a31`, keel highlights `#8b94a3`, outline `#0d0f12`), so it reads like a shadow you notice late.
- **Behaviour** (*my call*, offered with the mockup and not objected to):
  - The viper isn't there when the launcher starts opening. It slides out from behind the panel in about 0.5 s and rears.
  - While you type, it sways slightly and now and then draws its head back.
  - When you press Enter on an app, it strikes: a quick lunge at the chosen row as the app launches, then the launcher closes.
  - Nothing animates while the launcher is closed.

### Hidden details (all chosen by the user)

- **Spider under the island:** every few minutes a tiny spider lowers itself from the island's underside on a silk thread, hangs a moment and climbs back.
- **Chain clink:** described under Layout.
- **Film grain:** a barely-visible moving grain over the whole screen, as an Umbriel **screen effect** (custom GLSL preset). Very low intensity.
  - Umbriel's docs warn about the cost: a screen effect that reads `umbriel_time` redraws continuously up to `max_fps`, and any screen effect turns off direct scanout.
  - *My call:*
    - Cap animation frames with `[effects] max_fps` at about 24.
    - Switch the screen effect off whenever a fullscreen window is focused. Do this with a window rule if Umbriel offers one, otherwise from the shell's IPC watcher.
    - Measure Umbriel's own CPU on an idle desktop. If the moving grain costs more than about 2% there, fall back to static grain that doesn't read `umbriel_time`.
- **Smoke windows:** new windows fade in from a dark smoky blur, and closing windows dissolve into grain. These are Umbriel **animation effects** (custom GLSL presets on `windows_in` / `windows_out`).
- **Eyes in the dark:** very rarely (tens of minutes apart), two faint pale points blink once in a dark area of the wallpaper.

Ideas offered but **not** picked: idle cobweb, rusting chain link on low battery, midnight crow.

### Wallpapers

- **Starts with** `xe9223` (rain and hydrangea: a girl with an umbrella among hydrangeas, framed on black). It's already in `modules/theme/default.nix`.
  - It's **live**: rain falls only inside the framed picture (about 16–84% across and 24–76% down the 2560×1440 image), and the misty light behind the trees slowly brightens and dims.
  - The black border stays still.
- **The rest of the set**, all Wallhaven IDs:
  - `jeyo1m`: stormy ruins, already in `saved`. Live: slow cloud drift and a rare faint flash of distant lightning.
  - `mly2vm`: red eclipse behind a fence and towers.
  - `neko5k`: crows over a pale moon.
  - `2e2xyx`: vending machines in a dim alley.
  - `427owm`: Tokyo Tower through cherry blossom.
  - `rdrqz7`: Tokyo Tower at blue hour.
  - `vqv3p8`: dusk over Tokyo.
- **Switching (user decision):** no automatic rotation. A picker on a keybind (Mod+Ctrl+W, like niri) switches wallpaper, and the last choice is remembered across logins. The first login starts on `xe9223`.
- Only `xe9223` and `jeyo1m` need to be live. The others can be still.
- Fetch them like the niri rice does (`wallhaven name hash` → `pkgs.fetchurl`) into a separate folder, for example `~/.local/share/wallpapers/umbriel/`.

- **Screen.** The only screen is the laptop panel, `eDP-2`, at 1920×1200 (16:10) and 144 Hz. The wallpapers are 16:9 and get cover-cropped, so place the rain area and the eye positions in cropped-screen coordinates, not raw-image ones. Building for a single output is fine. If an external monitor appears later, the shell elements go on the primary output only.

### Colours

*My call, accepted:* a fixed, cool, near-monochrome palette (near-black, slate greys, off-white), not wallpaper-driven. Matugen recolouring belongs to the niri desktop. One restrained accent is allowed for the active chain link and the island's progress bars.

Inside Umbriel, the terminal stack follows this palette too, not the niri matugen colours. *My call:*
- Umbriel's terminal bind runs foot with its own config (`foot --config …/foot-umbriel.ini`), which uses the fixed palette.
- The Umbriel session sets `STARSHIP_CONFIG` to an Umbriel starship config.
- kew and cava are themed to the palette, and they inherit foot's 16 colours.
- The shared `rice-lock` screen keeps its matugen colours. It's shared on purpose.

### Music and TUI apps

- The user wants a different music player than `myx` for this desktop. *My call, accepted:* **kew** (local library, album art in the terminal, themeable), themed to the palette.
- **cava** as the visualiser.
- Keep `myx` and Spotify installed.
- The island's music view reads whatever is playing over MPRIS (playerctl).

## Goals

- At a glance it looks like a calm, dark desktop with almost nothing on it.
- The hidden details are rare and small enough that someone might use it for a day before noticing the spider.
- Nothing in it breaks the niri desktop. Both sessions coexist.

## Anti-goals

- Gore, skulls, jump scares, or anything loud or cartoonish.
- Hidden details firing often enough to get annoying or distracting. Err rare.
- The island or the corners covering content in fullscreen apps or games: hide them when a window is fullscreen.
- Any per-frame cost while nothing visible is animating. Live wallpapers must pause when fully covered or when a fullscreen window is focused.

## Constraints and facts

- **Install.** Before its removal in commit `b6b363d`, Umbriel was wired like this, and the same wiring should work again (see `git show b6b363d^:configuration.nix`):
  - flake inputs `umbriel` (`github:noctalia-dev/umbriel`) and `xdg-desktop-portal-umbriel`
  - NixOS `inputs.umbriel.nixosModules.default` with `programs.umbriel = { enable = true; portalPackage = …; }`
  - Home Manager `inputs.umbriel.homeModules.default` with `programs.umbriel.settings` (TOML)
  - **Don't** bring back Noctalia, DMS or SilentSDDM.
- **Config.** Umbriel is configured in live-reloaded TOML. Check it with `umbriel config validate`; the schema is `umbriel config schema --json`. If you define `keybinds`, that replaces the built-in binds, so define the full working set. Base them on the niri binds in `modules/niri/binds.kdl` (Mod+T foot, Mod+D firefox, Super+Alt+L lock, the media and brightness keys, and so on), so muscle memory carries over.
- **Effects.** Custom GLSL presets are `[effects.preset.<name>]` with `kind = "screen" | "animation" | …` and `shader = "<file>.glsl"`, selected by `[effects] screen = "<name>"` and `[animation.windows_in] effect = "<name>"`. The full reference is `docs/user/effects.md` in the Umbriel repo. The session lock detaches screen effects, which is fine. On NixOS, the bundled presets' path is in the install guide (`installation.md#using-bundled-effects`).
- **Shell.** Umbriel supports layer shell and session lock, so build the corners, island, launcher, spider and eyes in **Quickshell**, as a separate config such as `modules/umbriel/shell/` deployed to `~/.config/quickshell/umbriel` and started from Umbriel's `general.autostart`. Reuse patterns from `modules/shell/` (Notifications, Osd, Brightness) where it makes sense, but the look is new. Umbriel has no niri IPC, so workspace state must come from Umbriel's own IPC instead of `Niri.qml`. Its docs provide `subscribe workspaces`. Umbriel has no wallpaper feature of its own, so a Quickshell background layer won't clash with anything. It does start `graphical-session.target`, which confirms the session-scoping problem below.
- **Sessions must stay separate.** Today these Home Manager user services start on `graphical-session.target`, so they'd also start under Umbriel:
  - `awww`
  - the wallpaper restore service
  - the `rice-wall` timer

  The niri-only pieces must be scoped to the niri session. Umbriel's wallpaper handling must not fight them. The niri `qs -c rice` bar is started by niri's own `spawn-at-startup`, so it's already niri-only.
- **Login.** The custom SDDM theme (`modules/sddm/theme/Main.qml`) has **no session picker**; it always logs into the last session or index 0. Add a small, quiet session picker that matches the theme, so the user can choose niri or Umbriel.
- **Lock.** Keep the shared lock: `rice-lock` and `swayidle` from `modules/lock` should work under Umbriel through the session-lock protocol. Verify it does, including the "locker crashed" safety check from niri plan Task 9.
- **Repo rules.** These are the same as for the niri rice:
  - `git add` before `nix build`.
  - Build check: `nix build …toplevel --no-link`.
  - The user switches with `! nh os switch`. Never run sudo.
  - Tests stay green.
  - `niri validate` still passes.
- **Live wallpaper approach.** Both live wallpapers are a still image plus a light procedural animation (rain streaks and a glow inside the frame; cloud drift and a flash), not video files. *My call:* build them as a Quickshell background layer (shader or QML) in the Umbriel shell config.

## Done when

- At SDDM the user can pick Umbriel, log in, and see the hydrangea with rain inside the frame, chain links top-left, the island top-centre and faint status bottom-right.
- Switching workspaces clinks the link. Playing music, changing volume and getting a notification each morph the island.
- The launcher drops out of the island and launches apps.
- Film grain is visible only if you look for it, and windows open and close through smoke.
- Within an hour of normal use the spider has appeared at least once. The eyes are allowed to be rarer.
- Logging out and choosing niri gives the unchanged niri rice: matugen colours, the bar and the python (if done by then), and the rotation timer.
- Locking works in both sessions.
- With all windows maximised and idle for 60 s, the Umbriel shell and live wallpaper together average under 2% CPU.

## Left to the builder

- Exact sizes, spacing, fonts (keep the JetBrains Mono Nerd Font already installed unless something reads better), and animation timings within the "rare and subtle" brief.
- The island's internal state machine and priority when several things happen at once.
- How the eyes find a "dark area" of the current wallpaper. Hand-placed coordinates per wallpaper are fine.
- Umbriel layout and window-rule settings beyond what the effects and bar need. The old config in `b6b363d^` is a reasonable starting point.
