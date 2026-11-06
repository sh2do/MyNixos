# Umbriel Desktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A second login session on the Umbriel compositor: dark, quiet and slate-grey, with chain-link workspaces, a morphing island, a launcher that drops from the island with a horned viper wrapped around it, live wallpapers, film grain, smoke windows, and rare hidden details. The niri desktop stays exactly as it is.

**Architecture:**
- **NixOS:** Umbriel comes from its flake (NixOS module and portal). SDDM gains a session picker.
- **Home Manager:** a new `modules/umbriel/` module owns Umbriel's TOML (`programs.umbriel.settings`), its GLSL effect presets, a fixed-palette terminal stack, the Umbriel wallpapers, and a separate Quickshell config, `umbriel`, that draws the whole shell (background, corners, island, launcher, viper, spider, eyes). Umbriel starts it from `general.autostart`.
- **Session scoping:** services that belong to niri bind to `niri.service`, not `graphical-session.target`. The niri unit exists and binds that target.
- **Small CLIs:** `umbriel-wall` (wallpaper state) and `rice-dpms` (session-aware screen off) are bash, tested like the existing scripts.

**Tech Stack:** Umbriel (flake `github:noctalia-dev/umbriel`, NixOS and Home Manager modules), xdg-desktop-portal-umbriel, Quickshell 0.3.2 (QML: Wayland layer shell, `Quickshell.Services.Mpris`, `Quickshell.Services.Notifications`, `Quickshell.Services.Pipewire`, `DesktopEntries`), GLSL, foot, starship, kew, cava, SDDM (Qt6), bash.

**Spec:** `docs/superpowers/specs/2026-11-06-umbriel-desktop-design.md`

## Global Constraints

- Don't bring back Noctalia, DMS or SilentSDDM. The niri session must behave exactly as before, with the matugen colours, `qs -c rice`, the rotation timer and the python.
- **Palette** (fixed, in `modules/umbriel/shell/Palette.qml`):
  - `bg #0a0b0e`
  - `panel #060709` at 0.9 opacity
  - `raised #14161b`
  - `line #262a31`
  - `muted #7d8796`
  - `text #d6dbe3`
  - `bright #eef1f5`
  - `slate #4a4f58`
  - the single accent is `bright` used with a glow; there's no hue
  - viper: body `#4a4f58`, blotches `#262a31`, keel `#8b94a3`, outline `#0d0f12`
- **Font:** JetBrains Mono Nerd Font, already installed.
- **Screen:** single output `eDP-2`, 1920×1200 at 144 Hz. Wallpapers are cover-cropped from 16:9, so coordinates for the rain area and the eyes are in cropped screen space.
- **Wallpapers** (Wallhaven IDs; fetch them like `modules/theme/default.nix` does, into `~/.local/share/wallpapers/umbriel/`):
  - `xe9223` (start; live rain inside the frame)
  - `jeyo1m` (live clouds and lightning)
  - `mly2vm`, `neko5k`, `2e2xyx`, `427owm`, `rdrqz7`, `vqv3p8`
- **Wallpaper switching:** a picker on Mod+Ctrl+W, with the choice remembered across logins. No rotation.
- **Rare and subtle:**
  - The spider appears every 3–8 min, randomised.
  - The eyes appear every 25–60 min, randomised.
  - Nothing animates while it's off screen.
  - The shell's corners, island and status hide while a fullscreen window is focused.
- **CPU:** with all windows maximised and idle for 60 s, the Umbriel shell plus the live wallpaper average under 2%. Umbriel's own idle CPU with grain on also stays under about 2%; otherwise grain becomes static.
- **Umbriel facts** (from its docs):
  - IPC is JSON lines on `$UMBRIEL_SOCKET`. The CLI has `umbriel workspaces --json`, `umbriel subscribe workspaces,windows` and `umbriel msg <action>`.
  - Screen off is `umbriel msg dpms-off`.
  - Session environment goes in the `[environment]` table.
  - Effects are `[effects.preset.<name>] kind/shader` plus the selectors `[effects] screen`, `[animation.windows_in|windows_out] effect` and `[effects] max_fps`.
  - Validate with `umbriel config validate`. Defining `keybinds` replaces the defaults.
- `git add` before `nix build`. Build check: `nix build /etc/nixos#nixosConfigurations.nixos.config.system.build.toplevel --no-link`. The user switches with `! nh os switch`. Never run sudo.
- All `tests/*-test.sh` pass, and `niri validate` passes.

## Review Focus

1. **Locking under Umbriel.** `rice-lock` must engage through ext-session-lock, the idle timer must turn screens off with the Umbriel command (not `niri msg`), and if the locker dies the session stays locked. Covered by `test_dpms_uses_umbriel_when_umbriel_socket_set` (Task 1) and Task 1 step 7.
2. **Notification ownership.** Only one notification server runs per session. In Umbriel it's the island; `qs -c rice` never runs there. Task 1 step 7 checks `qs -c rice` is absent under Umbriel. Task 5 step 4 checks `notify-send`.
3. **Workspace IPC disconnects** (Umbriel restart or config reload). The chain links must reconnect, not freeze. Task 4 step 3 restarts the subscriber.
4. **Launcher with no matches or with odd desktop entries** (no icon, `NoDisplay`, Terminal=true). No crash, and Enter with nothing selected does nothing (no strike). Task 6 step 4.
5. **An unknown or missing wallpaper ID in the state file** falls back to `xe9223` instead of a black screen. Test `test_current_falls_back_on_unknown_id` in Task 3.

---

### Task 1: Umbriel session, scoping, login picker and lock

**Files:**
- Modify: `flake.nix` (inputs `umbriel` and `xdg-desktop-portal-umbriel`, both with `inputs.nixpkgs.follows = "nixpkgs"`), `configuration.nix` (import `inputs.umbriel.nixosModules.default`; `programs.umbriel = { enable = true; portalPackage = inputs.xdg-desktop-portal-umbriel.packages.${system}.default; }`)
- Create: `modules/umbriel/default.nix` (Home Manager: imports `inputs.umbriel.homeModules.default` and sets `programs.umbriel.settings`), `modules/umbriel/binds.nix` (the keybind table), `modules/lock/rice-dpms.sh`, `tests/rice-dpms-test.sh`
- Modify:
  - `modules/home.nix` (import `./umbriel`)
  - `modules/theme/default.nix`: the `awww` service, the restore service and the `rice-wall` timer get `PartOf`/`After`/`WantedBy` `niri.service` instead of `graphical-session.target`
  - `modules/lock/default.nix`: the 600 s timeout command becomes `rice-dpms off`
  - `modules/sddm/theme/Main.qml`: add a session picker and update the header comment

**Interfaces:**
- Produces:
  - `rice-dpms off|on`, which runs `umbriel msg dpms-off|dpms-on` when `$UMBRIEL_SOCKET` is set, else `niri msg action power-off-monitors` (for `off`; `on` is a no-op on niri, which wakes on input).
  - `modules/umbriel/default.nix`, which later tasks extend: `general.autostart` gets `qs -c umbriel` in Task 2; effects come in Task 8.

- [ ] **Step 1:** Write `tests/rice-dpms-test.sh` with `tests/lib.sh` stubs for `umbriel` and `niri`:
  - `test_dpms_uses_umbriel_when_umbriel_socket_set`: `UMBRIEL_SOCKET=/x rice-dpms off` logs `umbriel msg dpms-off`.
  - `test_dpms_uses_niri_otherwise`: logs `niri msg action power-off-monitors`.
  - `test_dpms_rejects_unknown_arg`: exits non-zero and logs nothing.
- [ ] **Step 2:** Run `bash tests/rice-dpms-test.sh`. Expected: FAIL.
- [ ] **Step 3:** Implement `rice-dpms.sh` and package it in `modules/lock/default.nix` with `writeShellApplication`. Run the tests and shellcheck. Expected: PASS and clean.
- [ ] **Step 4:** Add the inputs and modules. Write `binds.nix`, porting `modules/niri/binds.kdl` to Umbriel actions: same keys, same apps (Mod+T foot with the Umbriel config, from Task 2), Super+Alt+L `rice-lock`, the media, volume and brightness keys, workspace and focus moves. Mod+Space and Mod+Ctrl+W call `qs -c umbriel ipc call launcher toggle` and `… picker toggle`. Scope the niri-only services as listed. Run `git add`, then `nix flake lock`, then build. Expected: success. Then run `umbriel config validate` against the generated `~/.config/umbriel/config.toml` (copied out of the built Home Manager generation). Expected: no diagnostics.
- [ ] **Step 5:** Add the SDDM session picker: a small muted text row under the password field showing the current session name. Click or Left/Right cycles `sessionModel`, and `sddm.login(…, selectedIndex)` uses the selection. Run `nix build` on the theme alone, then `sddm-greeter-qt6 --test-mode --theme <out>/share/sddm/themes/rice`. Expected: it shows "niri", cycles to "Umbriel", and matches the theme's look.
- [ ] **Step 6:** Build the system. Before the user switches, give the recovery note: from a TTY, `sudo nixos-rebuild switch --rollback`. The user switches, logs out, picks Umbriel and logs in.
- [ ] **Step 7:** Under Umbriel, check:
  - Terminals open from the binds.
  - `systemctl --user is-active awww` reports `inactive`, and `pgrep -f 'qs -c rice'` finds nothing.
  - `pkexec true` prompts (the polkit agent from the cleanup plan).
  - Super+Alt+L locks and unlocks with the password.
  - Kill the locker (`pkill -f 'qs -c rice-lock'`): the session stays locked. Unlock from a TTY with `loginctl unlock-sessions`.

  Log back into niri and check it's unchanged: wallpaper, `awww` active, the bar, the timer.
- [ ] **Step 8:** Commit with the message `umbriel: session, niri-scoped services, SDDM session picker, session-aware dpms`.

### Task 2: Palette, terminal stack and shell skeleton

**Files:**
- Create:
  - `modules/umbriel/shell/shell.qml`: a `ShellRoot` that later tasks fill
  - `modules/umbriel/shell/Palette.qml`: a singleton with the Global Constraints values
  - `modules/umbriel/foot-umbriel.ini`: the palette as foot's 16 colours plus background and foreground
  - `modules/umbriel/starship-umbriel.toml`: a monochrome two-line prompt
  - `modules/umbriel/kew.conf`: kew's colour settings mapped to the palette
  - `modules/umbriel/cava.conf`: gradient from `slate` to `bright`
- Modify: `modules/umbriel/default.nix`:
  - deploy `quickshell/umbriel` from `./shell` (filter `.qml`, `.js`, `.glsl`, `.json`, `.svg`)
  - deploy the foot, starship, kew and cava configs to `~/.config/umbriel-term/…` and their app paths
  - `general.autostart = [ "qs -c umbriel" ]`
  - `environment.STARSHIP_CONFIG = "~/.config/umbriel-term/starship.toml"`, with the path expanded
  - Mod+T spawns `foot --config ~/.config/umbriel-term/foot.ini`
  - add the `kew` and `cava` packages

- [ ] **Step 1:** Write the files. Run `qmllint` on the QML. Expected: no errors.
- [ ] **Step 2:** Build, switch, and log into Umbriel. Expected: Mod+T opens foot in slate colours with the monochrome prompt. `kew` and `cava` start in the palette. Under niri, foot still uses matugen colours.
- [ ] **Step 3:** Commit with the message `umbriel: slate palette, terminal stack and shell skeleton`.

### Task 3: Wallpapers: state CLI, live background, picker

**Files:**
- Create:
  - `modules/umbriel/umbriel-wall.sh`
  - `tests/umbriel-wall-test.sh`
  - `modules/umbriel/shell/Background.qml`: a `PanelWindow` on the Background layer, full screen
  - `modules/umbriel/shell/RainFrame.qml`
  - `modules/umbriel/shell/StormSky.qml`
  - `modules/umbriel/shell/Picker.qml`
  - `modules/umbriel/shell/walls.json`: id → `{file, live: "rain"|"storm"|null, rainRect?, eyes: [{x,y}]}` in cropped-screen fractions
- Modify: `modules/umbriel/default.nix` (fetch the 8 wallpapers; package `umbriel-wall`)

**Interfaces:**
- Produces:
  - `umbriel-wall current` prints the id (default `xe9223`). `umbriel-wall set <id>` validates against the files in `$UMBRIEL_WALL_DIR` (default `~/.local/share/wallpapers/umbriel`) and writes `$UMBRIEL_STATE_DIR/current` (default `~/.local/state/umbriel`). `umbriel-wall list` prints the ids.
  - `Background.qml` exposes `wallId: string` and `paused: bool`. Task 7 reads `wallId` for the eyes.

- [ ] **Step 1:** Write `tests/umbriel-wall-test.sh` (using `tests/lib.sh`, with the state and wall dirs in `$TMP`):
  - `test_current_defaults_to_hydrangea`: no state file, prints `xe9223`.
  - `test_set_then_current`: `set mly2vm` then `current` prints `mly2vm`.
  - `test_set_rejects_unknown`: `set nope` exits non-zero and leaves the state unchanged.
  - `test_current_falls_back_on_unknown_id`: the state file holds `gone`, so `current` prints `xe9223`.
  - `test_list_prints_all_ids`: with 8 fake files, it prints 8 sorted lines.
- [ ] **Step 2:** Run them. Expected: FAIL. Implement `umbriel-wall.sh` (bash, `set -euo pipefail`, `writeShellApplication`). Run the tests and shellcheck. Expected: PASS and clean.
- [ ] **Step 3:** Build the background:
  - **The still image** is cover-cropped to the screen.
  - **`RainFrame`:** for `live: "rain"`, inside `rainRect` (measure it on the cropped 1920×1200 image; the frame sits around 16–84% across and 24–76% down of the 16:9 source, then cropped), draw 2 layers of slanted streaks and a slow brightness breathing (9 s) on the misty upper-centre. Use a `ShaderEffect` or a QML `ParticleSystem`, whichever measures cheaper.
  - **`StormSky`:** for `"storm"`, a slow translate and scale drift (40 s, alternate) plus a lightning flash every 8–20 s (randomised), as a short radial brightening top-right.
  - **Pausing:** `paused` turns true while any window is fullscreen or the visible workspace has a maximised window covering the output, worked out from `umbriel subscribe windows,workspaces` (shared with Task 4 through a `UmbrielIpc.qml` singleton, created here). When paused, the animations stop.
- [ ] **Step 4:** Build `Picker.qml`, a centred overlay of thumbnails for `umbriel-wall list`, in the slate style. Selecting one runs `umbriel-wall set <id>`, and `Background` reloads on the state file changing (watch with `FileView`). Escape closes it. Register IPC `picker toggle`.
- [ ] **Step 5:** Run `qs -c umbriel` under Umbriel. Check:
  - It starts on the hydrangea with rain only inside the frame.
  - Mod+Ctrl+W lets you pick `jeyo1m`, and clouds drift with an occasional flash.
  - After logging out and back in, `jeyo1m` is still the wallpaper.
  - Maximise a window, wait 60 s, and measure. The shell's CPU is under 2%.
- [ ] **Step 6:** Commit with the message `umbriel: wallpapers, live rain and storm, picker`.

### Task 4: Corners: chain workspaces and status

**Files:**
- Create: `modules/umbriel/shell/UmbrielIpc.qml` (created in Task 3; extend it), `modules/umbriel/shell/Chain.qml`, `modules/umbriel/shell/Status.qml`
- Modify: `modules/umbriel/shell/shell.qml`

**Interfaces:**
- Consumes `UmbrielIpc` from Task 3. It exposes:
  - `workspaces: var` (an array of `{id, index, active, occupied}` for `eDP-2`)
  - `fullscreen: bool`
  - `focusWorkspace(index)`
- Produces `UmbrielIpc.fullscreen`. Tasks 5 and 6 use it to hide.

- [ ] **Step 1:** Implement `UmbrielIpc` with a `Process` running `umbriel subscribe workspaces,windows`, parsing each JSON line. If the process exits, restart it after 1 s.
- [ ] **Step 2:** Implement the two corners:
  - **`Chain`** (top-left, 20 px in): one link per workspace, 16×9 rounded outlines with a 2 px stroke, overlapping by 4 px. Empty links use `line`, occupied ones `muted`, the active one `bright` with a soft glow. When the active workspace changes, the new link swings −14° → +9° → −3° → 0 over about 600 ms. Clicking a link focuses its workspace.
  - **`Status`** (bottom-right): wifi, bluetooth and battery as glyphs plus the battery number, in `muted` at 11 px. Use UPower and NetworkManager through Quickshell services or small `Process` reads.

  Hide both while `fullscreen`.
- [ ] **Step 3:** Check under Umbriel:
  - Switching workspaces with keys and by clicking moves the bright link with the clink.
  - Run `umbriel msg config-reload`, or restart Umbriel's config, then switch again. The links still update.
  - A fullscreen video hides both corners.
- [ ] **Step 4:** Commit with the message `umbriel: chain-link workspaces and status corner`.

### Task 5: The island

**Files:**
- Create: `modules/umbriel/shell/Island.qml`, `modules/umbriel/shell/IslandQueue.js` (`.pragma library`), `tests/island-queue-test.js` (node)
- Modify: `modules/umbriel/shell/shell.qml`

**Interfaces:**
- Produces:
  - `IslandQueue.next(state, event, nowMs) -> state`, where `state` is `{view: "clock"|"music"|"notify"|"osd", until: ms, pending: [...]}` and `event` is `{type: "notify"|"osd"|"music"|"tick", payload}`. Priority: osd > notify > music > clock. A view holds for osd 1.5 s, notify 5 s (critical stays until dismissed), and music 4 s after a track change.
  - `Island.qml` exposes `openLauncher()` and `closeLauncher()` and an `expanded: bool`, plus `anchorBottom: point` (the underside centre). Tasks 6 and 7 use those.

- [ ] **Step 1:** Write `tests/island-queue-test.js`:
  - `test_osd_preempts_notify_then_returns`
  - `test_critical_notify_stays_until_dismissed`
  - `test_music_shows_on_track_change_then_clock`
  - `test_tick_expires_view`
- [ ] **Step 2:** Run `nix run nixpkgs#nodejs -- tests/island-queue-test.js`. Expected: FAIL. Implement `IslandQueue.js`, then run again. Expected: PASS.
- [ ] **Step 3:** Implement `Island.qml`:
  - a black pill (`panel` colour) at top-centre, 76×28 as the clock
  - it morphs to music (about 280 px: equaliser bars, title · artist, time), notify (about 300×64: icon, title, body; click dismisses) and osd (about 220 px: glyph, bar, value)
  - width and height animate with a springy curve (`Easing.OutBack`, around 350 ms)
  - wire up `NotificationServer` (the only one in this session), MPRIS for the active player, Pipewire default-sink volume, and brightness through the same approach as `modules/shell/Brightness.qml`
  - the volume and brightness keys in `binds.nix` must change the values, and the island reacts to the change
  - hide while `fullscreen`, except critical notifications
- [ ] **Step 4:** Check:
  - Play music in kew, and the island shows the track.
  - `notify-send hi` shows for 5 s.
  - `notify-send -u critical x` stays until clicked.
  - The volume and brightness keys show the OSD and return to the clock.
- [ ] **Step 5:** Commit with the message `umbriel: the island`.

### Task 6: Launcher and horned viper

**Files:**
- Create: `modules/umbriel/shell/Launcher.qml`, `modules/umbriel/shell/Viper.qml`, `modules/umbriel/shell/fuzzy.js`, `tests/fuzzy-test.js`

**Interfaces:**
- Consumes `Island.openLauncher()`, `closeLauncher()` and `expanded` from Task 5.
- Produces:
  - `fuzzy.rank(query, entries) -> entries` (subsequence match; prefix and word-start bonuses; ties broken by name)
  - IPC `launcher toggle`
  - `Viper.qml` with `phase: "hidden"|"entering"|"idle"|"strike"` and `strikeTarget: point`

- [ ] **Step 1:** Write `tests/fuzzy-test.js`:
  - `test_prefix_beats_substring` ("fi" ranks Firefox and Files above Thunderbird-like matches)
  - `test_no_match_returns_empty`
  - `test_case_insensitive`

  Run it. Expected: FAIL. Implement, then run again. Expected: PASS.
- [ ] **Step 2:** Implement `Launcher`:
  - The island grows down into a 240×320 panel: the search field, then up to 8 rows from `DesktopEntries.applications`, skipping `NoDisplay` entries. Terminal entries run in Umbriel foot.
  - Typing filters with `fuzzy.rank`. Up/Down moves the selection. Enter launches the selected entry. Escape or a click outside closes.
- [ ] **Step 3:** Implement `Viper`. It's drawn the same way as the niri python (layered `ShapePath`s) in the viper colours:
  - a stubby body, about 17 px, wound twice around the panel diagonally, front crossings only between rows (never over the search field or the selected row)
  - the head reared over the top-right corner: a broad triangle, two horns, vertical pupils
  - **Phases:** `entering` slides the body out from behind the panel over 0.5 s. `idle` sways (head ±4° every 3 s) and draws back slightly now and then. `strike` lunges at the selected row over about 150 ms, then the launch happens and the launcher closes. While `hidden`, nothing runs.

  Reference: `viper-launcher.html`, option B.
- [ ] **Step 4:** Check:
  - Open, type `fir`, Enter. The viper strikes at Firefox, and Firefox launches.
  - Type gibberish. The list is empty and Enter does nothing (no strike).
  - An entry with no icon shows a fallback glyph.
  - `Terminal=true` entries open in foot.
- [ ] **Step 5:** Commit with the message `umbriel: launcher with horned viper`.

### Task 7: Hidden details: spider and eyes

**Files:**
- Create: `modules/umbriel/shell/Spider.qml`, `modules/umbriel/shell/Eyes.qml`
- Modify: `modules/umbriel/shell/walls.json` (eye coordinates for each of the 8 wallpapers, placed by hand in dark areas)

**Interfaces:**
- Consumes `Island.anchorBottom` and `Island.expanded` (Task 5), `Background.wallId` and `paused` (Task 3), and `UmbrielIpc.fullscreen` (Task 4).

- [ ] **Step 1:** Implement both details:
  - **`Spider`:** every 3–8 min (randomised), while the island is collapsed and nothing is fullscreen, a 13 px spider lowers on a 1 px silk line from the island's underside, about 60 px over 1.2 s. It hangs for 2–4 s with a tiny sway, then climbs back. Nothing runs between appearances; schedule it with a single-shot `Timer`.
  - **`Eyes`:** every 25–60 min, at one of the current wallpaper's `eyes` points, two 3 px pale dots (8 px apart) fade in, blink once and fade out over about 1.2 s. Skip if `paused` or the point is covered by a window (ask `UmbrielIpc` for window rectangles on the active workspace).
  - Add the environment variable `UMBRIEL_HIDDEN_DEBUG=1` to shorten both intervals to 10 s for testing.
- [ ] **Step 2:** Run `UMBRIEL_HIDDEN_DEBUG=1 qs -c umbriel`. Expected: the spider drops from the island, and the eyes blink in a dark area of each wallpaper. Cycle through all 8 with the picker and adjust the `walls.json` points until each sits in a dark spot.
- [ ] **Step 3:** Commit with the message `umbriel: spider and eyes`.

### Task 8: Effects: film grain and smoke windows, then final checks

**Files:**
- Create: `modules/umbriel/effects/grain.glsl`, `modules/umbriel/effects/smoke-in.glsl`, `modules/umbriel/effects/smoke-out.glsl`
- Modify: `modules/umbriel/default.nix`:
  - `effects.preset.grain = { kind = "screen"; shader = …; }`
  - `smoke-in` and `smoke-out` with `kind = "animation"`
  - `effects.screen = "grain"` and `effects.max_fps = 24`
  - `animation.windows_in.effect = "smoke-in"` and `windows_out = "smoke-out"`, with durations of about 280 and 220 ms
  - deploy the `.glsl` files next to the generated config so the relative `shader` paths resolve

- [ ] **Step 1:** Write the shaders against the uniforms that `docs/user/effects.md` and Umbriel's bundled presets define (read a bundled preset first, for example `share/umbriel/effects/screen/vignette`):
  - **grain:** hash noise at about 4% intensity, luminance-weighted (less in highlights), reseeded from `umbriel_time` at 24 Hz.
  - **smoke-in:** a dark noise-driven blur that resolves into the window.
  - **smoke-out:** the window dissolves into grain-like noise and fades.

  Run `umbriel config validate`. Expected: no diagnostics.
- [ ] **Step 2:** Make grain go away for fullscreen. Find the runtime effect action in `umbriel msg` (`docs/user/actions.md` and `ipc.md`: effect selection with source `runtime`). From `UmbrielIpc`, when `fullscreen` becomes true, select no screen effect for `eDP-2`, and restore `grain` when it ends. If no runtime action exists, document that and keep grain on.
- [ ] **Step 3:** Measure:
  - Idle desktop for 60 s: Umbriel's own CPU (`top -p $(pgrep -x umbriel)`). If it's above about 2%, switch grain to the static variant (no `umbriel_time`), re-measure and note it.
  - All windows maximised, idle for 60 s: `qs -c umbriel` is under 2%.
  - Record both figures in the commit message.
- [ ] **Step 4:** Final regression:
  - All `tests/*-test.sh` and node tests pass.
  - `niri validate` passes.
  - A full build from a fresh clone succeeds.
  - Log into niri and check it's unchanged.
  - Log into Umbriel and walk through the spec's "Done when" list.
  - Steam launches a game under Umbriel (Xwayland on demand), and grain is off while it's fullscreen.
- [ ] **Step 5:** Update the README: a new "Umbriel desktop" section (how to pick it at login, keys, `umbriel-wall`) and the layout block. Commit with the message `umbriel: film grain and smoke windows; README`.
