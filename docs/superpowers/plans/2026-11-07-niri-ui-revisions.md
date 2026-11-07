# Niri UI Revisions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the niri desktop's top pill (living media), bottom bar (pond glass), notifications and OSD (grouped cards, water-level capsule) and rofi menus (glassier, with static drips), as on the approved canvas boards.

**Architecture:** Quickshell QML in `modules/shell/` and rofi themes in `modules/rofi/`, all coloured by matugen through `Theme.qml` and the rofi colour file. Pure logic, such as grouping, visualiser parsing and the OSD wave phase, lives in `.pragma library` JS with node tests. Art that doesn't move is drawn once.

**Tech Stack:** Quickshell 0.3.2 / Qt 6 QML, rofi, matugen templates, cava (raw mode), node tests, bash config tests.

**Spec:** `docs/superpowers/specs/2026-11-07-niri-ui-revisions-design.md`. The mockups are the NiriTop, NiriBottom, NiriNotify and NiriMenus boards on the canvas linked there; their sources are in the session scratchpad at `serpents/project/Niri*.dc.html`.

## Global Constraints
- **niri only.** Only `modules/shell/`, `modules/rofi/`, `modules/theme/` (templates), `tests/` and `docs/RICE.md` change. Umbriel is untouched.
- **Colours:** matugen only, through `Theme.qml` or the rofi colours. No hard-coded hues.
- **Never kill `qs -c rice`.** The user is using it. Test with a scratch copy, `qs -p <copy>`, using `RICE_BAR_PINNED=1` where useful. Put a test bar on the Overlay layer only briefly, and close it straight after the screenshot.
- **Budgets:**
  - the bottom bar shown and idle is no costlier than today (koi at about 15%);
  - the top pill with music adds ≤ 2%;
  - the OSD visible costs ≤ 3%;
  - the menus have no runtime cost.
- **Animation:** animations driven by Qt render at 144 Hz, so drive motion from your own capped clock, as Koi.qml does with its 48 Hz tick.
- **Git and Nix:**
  - Never sudo or switch.
  - `git add` before `nix build /etc/nixos#nixosConfigurations.nixos.config.system.build.toplevel --no-link`.
  - Commit by path, with messages ending in `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Don't push.

## Review Focus
1. **No music player, or a player with no art, length or position.** The pill falls back cleanly to the window title, or shows no art and no progress line, with no errors.
2. **Notifications without actions, icons or app names, and floods** (20 from one app). Grouping caps the visible stack and never grows off-screen.
3. **Rapid volume key repeats.** The OSD ripple restarts smoothly, and the level is never stale.
4. **The palette changing while a menu, toast or OSD is open.** Colours follow matugen, and the drip PNG regenerates through matugen's post_hook.
5. **The raven option (`RICE_MASCOT=raven`).** The pond-glass bar keeps the raven's perch on its top rim at the right end.

---

### Task N1: Top pill, the living media pill

**Files:**
- Modify: `modules/shell/TopPill.qml`
- Create: `modules/shell/media.js`
- Test: `tests/media-test.js`

**Interfaces (`media.js`, pure):**
- `parseCava(line: string, bars: 5) -> number[]`: values 0–1. A malformed line gives all zeros.
- `progress(position, length) -> 0..1`: 0 when length ≤ 0 or unknown.
- `fmtArtist(title, artist) -> {top, bottom}`: falls back to the title alone.

**Steps:**
- [ ] **Step 1:** Write the failing tests (`test_parse_cava`, `test_parse_cava_garbage`, `test_progress_unknown_length`, `test_artist_fallback`), run them, and watch them fail.
- [ ] **Step 2:** Implement `media.js`. Tests pass.
- [ ] **Step 3:** Implement the pill, per the NiriTop "A" board:
  - 40 px tall while playing;
  - 28 px art (rounded 8) with a glow in the art's dominant colour, sampled once per track, with matugen `primary` as the fallback;
  - title and artist on two lines;
  - a 5-bar visualiser fed by `cava` raw output through a Process, at ≤ 30 Hz, running only while it plays and the pill is shown;
  - a 2 px progress line inside the bottom rim;
  - previous, play/pause and next swapped in on hover.

  Everything else (window title, drop-in, tuck-away, fullscreen hide) is unchanged. If cava isn't in the system packages, add it in `modules/shell/default.nix` or reuse the existing package.
- [ ] **Step 4:** Take screenshots: playing, hovered, no music. Measure the CPU delta while playing: ≤ 2%.
- [ ] **Step 5:** Commit with the message `rice: living media pill`.

### Task N2: Bottom bar, pond glass
Runs after the serpents plan's Task 4N, which removes the python and adds the raven.

**Files:**
- Modify: `modules/shell/BottomBar.qml`, `Workspaces.qml`, `Toggles.qml`, `Chip.qml`, `Clock.qml` (as needed)

**Look**, per the NiriBottom "A" board:
- the bar is 42 px;
- a top-rim highlight, an inner gradient and a reflection band;
- widget groups on three faint stones;
- an "on" toggle shows a lit icon and a 3 px dot;
- the active workspace is a glowing capsule;
- when hidden, a visible 120 × 2 water line is centred at the edge, and touching the edge still raises the bar;
- the koi still swim under the glass;
- with `RICE_MASCOT=raven`, the raven perches on the top rim at the right end.

**Steps:**
- [ ] **Step 1:** If any logic is pure (e.g. stone grouping widths), test it first.
- [ ] **Step 2:** Implement. Static decorations are drawn once.
- [ ] **Step 3:** Take screenshots: shown, hidden, raven. Measure: the bar shown and idle is no costlier than before (compare in the same session), and hidden it's about 0.3%.
- [ ] **Step 4:** Run `bash tests/config-test.sh`. Expected: it passes.
- [ ] **Step 5:** Commit with the message `rice: pond-glass bottom bar`.

### Task N3: Notifications and OSD

**Files:**
- Modify: `modules/shell/Notifications.qml`, `Osd.qml`
- Create: `modules/shell/notify-group.js`
- Test: `tests/notify-group-test.js`

**Interfaces (`notify-group.js`, pure):**
- `group(list: [{id, app, icon, summary, body, time, urgency, actions}]) -> [{app, icon, count, latest, stack: up to 2 older, critical}]`: newest group first, at most 4 groups.
- `age(now, time) -> "now" | "2m" | "1h" | …`

**Steps:**
- [ ] **Step 1:** Write the failing tests: `test_groups_by_app_newest_first`, `test_stack_caps_at_two`, `test_max_four_groups`, `test_missing_app_and_icon` (fall back to "unknown" and a generic glyph), `test_critical_flag`, `test_age_labels`.
- [ ] **Step 2:** Implement `notify-group.js`. Tests pass.
- [ ] **Step 3:** Implement the cards, per the NiriNotify "A" board:
  - app icon, name, count and age;
  - action buttons that invoke the notification's real actions;
  - the stack peeking underneath;
  - a 3 px timeout line;
  - critical cards stay until clicked.
- [ ] **Step 4:** Implement the OSD as a 56 × 168 water-level capsule:
  - the wavy surface is a Shape or ShaderEffect;
  - each change sends a ripple;
  - it animates only while visible, on a clock at ≤ 60 Hz;
  - rapid key repeats restart the ripple smoothly.
- [ ] **Step 5:** Take screenshots. Run `notify-send -a test -A reply=Reply hi` (three of them, from two apps) and a critical one. Measure the OSD while visible: ≤ 3%.
- [ ] **Step 6:** Commit with the message `rice: grouped notifications and water OSD`.

### Task N4: Rofi, glassier, with static drips

**Files:**
- Modify: `modules/rofi/theme.rasi` (and the matugen rofi colour template, if the alpha values need it), `modules/theme/matugen.toml`
- Create: `modules/theme/templates/drips.svg` (a matugen template), rendered to `~/.cache/rice/drips.png` by a post_hook with `rsvg-convert`

**Look:**
- keep the current layout;
- add translucency, a top-rim highlight and an inner gradient;
- static water drips hang from the window's bottom edge, as a rofi `background-image`, on a child widget sized to the strip;
- if rofi allows it, a small drip under the selected row.

**Blur:** check whether niri 26.04 supports background blur for layer surfaces. Read its docs or the wiki in the niri flake input, and validate with `niri validate`. If it does, add a layer-rule for rofi's namespace. If not, use translucency alone, and say so in the report.

**Steps:**
- [ ] **Step 1:** Add the template and post_hook. Run `bash tests/config-test.sh`, adding a test that the matugen config has the drips template.
- [ ] **Step 2:** Restyle `theme.rasi`. Take screenshots: open `rice-menu apps` and `rice-menu power` briefly, take a `grim` shot, then close them.
- [ ] **Step 3:** Commit with the message `rice: glassy dripping menus`.

### Task N5: Docs
Update `docs/RICE.md`: the bar, the pill, notifications and OSD, menus, the tests list and the file map. Commit with the message `docs: niri UI revisions`.
