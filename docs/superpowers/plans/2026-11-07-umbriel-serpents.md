# Umbriel Serpents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A richly detailed reticulated python coiled on Umbriel's bottom-right status corner and a venom-dripping viper hanging from under the island, animated smoothly at the display's refresh rate.

**Architecture:** Each body is a skin strip drawn once into a texture and bent along a spine on the GPU. A `ShaderEffect` with a `GridMesh` does the bending; its vertex shader reads 24 spine control points passed as `vec4` uniforms. Only the uniforms and the transforms of small, once-drawn parts (heads, jaws, eyes, drops) change per frame, driven by a delta-time `FrameAnimation`. All poses, schedules and physics live in pure `.pragma library` JS with node tests.

**Tech Stack:**
- Quickshell 0.3.2, Qt 6 QML
- QtQuick Shapes and `ShaderEffect`: GLSL 440, compiled to `.qsb` by `qsb` at Nix build time
- node for the tests

**Spec:** `docs/superpowers/specs/2026-11-07-umbriel-serpents-design.md` (mockups: the "Umbriel serpents" canvas linked there)

## Global Constraints

- **Umbriel only.** Files live under `modules/umbriel/`, plus `tests/`. Nothing under `modules/shell/` (the niri desktop) changes.
- **Palette:**
  - Colours come from `modules/umbriel/shell/Palette.qml`. Add new roles there.
  - The only colour outside the slate ramp is the python's iridescent sheen, the shed's milky-blue eyes, and the venom's `bright` with a glow.
- **Nothing is rebuilt per frame.** A Shape's path never changes during animation. Per frame, only ShaderEffect uniform properties and item transforms (x, y, rotation, scale, opacity) change.
- **The clock:**
  - One `FrameAnimation` per serpent. All motion uses its `frameTime` delta, never a fixed tick.
  - It runs only while the serpent is visible and not paused. Visible means `!UmbrielIpc.fullscreen`; not paused means Background's `paused` is false.
  - `UMBRIEL_SERPENT_FPS=<n>` caps it by skipping updates until 1/n s has passed.
- **CPU budget:** `qs -c umbriel` with both serpents idle on screen is **≤ 4% of a core at 144 Hz**, measured over 20 s with `top`.
- **Shaders:** files `*.vert` / `*.frag` in `modules/umbriel/shell/`, `#version 440`. The `umbriel-shell` derivation compiles both kinds with `qsb --qt6`.
- **Testing:** in nested Umbriel, as in `.superpowers/sdd/2026-11-06-umbriel-desktop/context.md`. Never run sudo. `git add` before `nix build`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Timings:**

  | What | Value |
  |---|---|
  | breath | ~5 s |
  | tongue flick | every 8–15 s |
  | yawn | every 25–45 min; hold ~1.2 s |
  | hunt | S after the pointer is still 3 s; strike after a further 1 s; strike ~120 ms; recoil ~600 ms |
  | bulge | ~20 s per bulge; at most 3 |
  | night | 21:00–06:00 |
  | shed | weekly; dull for a day; peel ~8 s; ghost fades over 60 s |
  | drip interval | ~4 s when calm, ~0.6 s at full load; load read every 2 s |
  | viper retreat | ~0.6 s; returns 2 s after fullscreen ends |
  | drop with no window below | fades by 300 px |

## Review Focus

1. **Several outputs, or the status corner moving.** The python must stay wrapped around Status, never floating off it. Covered by Task 3's `test_python_pose_wraps_status_box`.
2. **Missing or unexpected input.** A notice arriving while a swallow is already in progress queues instead of being lost or duplicated, with at most 3 bulges. Covered by Task 4's `test_bulges_queue_and_cap_at_three`.
3. **Time jumps** (suspend/resume, clock changes) must not fire a burst of yawns or sheds or skip the shed schedule. Covered by Task 4's `test_schedule_survives_time_jump`.
4. **A huge frame delta after a stall** (dt > 0.25 s) must not fling drops or snap poses. Covered by Task 5's `test_large_dt_is_clamped` and Task 1's `test_step_clamps_dt`.
5. **A missing or unparsable `/proc/stat` or state file.** The viper falls back to the calm drip rate and the shed schedule restarts, rather than erroring. Covered by Task 5's `test_load_parse_garbage` and Task 4's `test_shed_state_garbage`.

---

### Task 1: Spine maths

**Files:**
- Create: `modules/umbriel/shell/serpent-spine.js`
- Test: `tests/serpent-spine-test.js` (same vm-loader pattern as `tests/umbriel-state-test.js`)

**Interfaces:**
- Produces (all pure; points are `{x, y}`, samples are `{x, y, tx, ty, s}` with a unit tangent and arc length `s`):
  - `SPINE_POINTS = 24`
  - `catmull(points: Point[], t: number) -> Point`: centripetal Catmull-Rom. `t` in [0, 1] spans the whole chain, and the ends are clamped.
  - `sample(points: Point[], n: number) -> Sample[]`: n samples, evenly spaced by arc length.
  - `resample(points: Point[], n = SPINE_POINTS) -> Point[]`: n control points, evenly spaced by arc length. This is what goes to the shader.
  - `pack(points: Point[], widths: number[]) -> {x, y, z, w}[]`: one `vec4` per control point, `(x, y, widthScale, 0)`.
  - `widthAt(u: number, bulges: {u, size}[]) -> number`: the width scale at u. The base taper is a tail tip of 0.2 at u = 1, full width over u 0.1–0.7, and 0.85 at the neck (u = 0, head end). Each bulge adds `size * exp(-((u - b.u) / 0.035)²)`.
  - `step(dt: number) -> number`: returns dt clamped to [0, 0.05], for every animation step.

- [ ] **Step 1: Write the failing tests.** All values are in px.
  - `test_catmull_passes_through_points`: `catmull(pts, i / (pts.length - 1))` is within 1e-6 of `pts[i]` for every i.
  - `test_sample_is_evenly_spaced`: on an S-shaped 6-point chain, consecutive `s` gaps differ by under 2%, and tangents are unit length.
  - `test_resample_returns_24_points`, with the first and last points equal to the chain's ends.
  - `test_width_tapers_to_tail`: `widthAt(1, []) ≈ 0.2`, `widthAt(0.4, []) = 1`, `widthAt(0, []) ≈ 0.85`.
  - `test_bulge_adds_width_locally`: with `[{u: 0.5, size: 0.6}]`, width at 0.5 is ≥ 1.55 and width at 0.7 is under 1.01.
  - `test_step_clamps_dt`: `step(3)` is 0.05, `step(-1)` is 0, `step(0.007)` is 0.007.
- [ ] **Step 2:** Run `nix run nixpkgs#nodejs -- tests/serpent-spine-test.js`. Expected: FAIL (`catmull is not a function`).
- [ ] **Step 3: Implement** in `serpent-spine.js` (`.pragma library`, ES5 `var`/`function` like `modules/shell/koi-motion.js`).
- [ ] **Step 4:** Run again. Expected: all PASS.
- [ ] **Step 5:** Commit with the message `umbriel: serpent spine maths`.

### Task 2: The GPU body (Serpent.qml and shaders)

**Files:**
- Create:
  - `modules/umbriel/shell/Serpent.qml`
  - `modules/umbriel/shell/serpent.vert`
  - `modules/umbriel/shell/serpent.frag`
  - `modules/umbriel/shell/serpent-shadow.frag`
- Modify: `modules/umbriel/default.nix` (the `umbriel-shell` derivation)
  - Add `".vert"` to the source filter.
  - Compile `$out/*.vert` with `qsb --qt6` like the `.frag` files.

**Interfaces:**
- Consumes: `serpent-spine.js` from Task 1.
- Produces: `Serpent.qml`, an Item filling its parent window.
  - Inputs:
    - `property Item skin`: any Item, drawn once into a hidden `ShaderEffectSource`. `live: false`, with one `scheduleUpdate()` after it completes.
    - `property real bodyWidth` (px).
    - `property var spine: Point[]` (control points; Serpent resamples).
    - `property var widths: number[]` (per control point; defaults to `widthAt` with no bulges).
    - `property real time` (s), `property real sheen` (0–1), `property real dull` (0–1, for the shed), `property real ripplePhase`, `property real rippleAmp`.
    - `property point shadowOffset: Qt.point(3, 5)`.
  - Exposes `readonly property var head: Sample` and `readonly property var tail: Sample`, so other items can attach at the ends.
- **Uniforms.** The ShaderEffect properties `s0` … `s23` are `vector4d`; `serpent.vert` declares them in its uniform block. It also takes `bodyWidth`, `time`, `sheen`, `dull`, `ripplePhase`, `rippleAmp` and `qt_Matrix` / `qt_Opacity`.
- **Mesh:** `GridMesh { resolution: Qt.size(128, 4) }`. The vertex shader maps texcoord (u, v) to the spine:
  1. Catmull-Rom between the 24 uniform points at `u * 23`.
  2. Offset along the normal by `(v - 0.5) * bodyWidth * width`, where width is the point's `.z`, interpolated.
- **`serpent.frag`:**
  - samples the skin;
  - multiplies by rounded shading `0.55 + 0.45 * sin(v * π)`;
  - adds a specular line at v ≈ 0.3;
  - adds the iridescent sheen, a thin-film hue from `dot(tangent, normalize(vec2(-0.6, -0.8)))` and `time`. Its strength is `sheen * smoothstep` near v 0.25–0.4;
  - applies ripple brightness `1 + rippleAmp * sin(u * 40 - ripplePhase)`;
  - mixes toward grey by `dull`.
- **`serpent-shadow.frag`:** black at alpha `0.45 * sin(v * π)²`. It is drawn first, offset by `shadowOffset`.

- [ ] **Step 1: Build check.** Add the `.vert` compile to `default.nix`, `git add`, then run `nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel --no-link`. Expected: it builds, and `serpent.vert.qsb` exists in the `umbriel-shell` output (`ls $(nix path-info …umbriel-shell)`).
- [ ] **Step 2: Implement `Serpent.qml`**, with a test harness in the scratchpad:
  - The harness is a PanelWindow (Overlay layer, mask empty) holding a Serpent whose skin is a striped test strip.
  - Its spine is an S that animates with `time`.
  - It grabs `scene.grabToImage` at t = 0.5 s and t = 1.5 s.

  Expected:
  - the strip follows the S with no tearing at the ends;
  - stripes stay perpendicular to the body;
  - the shadow sits under it, offset.
- [ ] **Step 3: Measure.** With the harness running for 20 s at 144 Hz, `top` CPU for the qs process is **≤ 2%**. Write the figure in the commit message.
- [ ] **Step 4:** Commit with the message `umbriel: GPU-bent serpent body`.

### Task 3: The python: skin, head and idle life

**Files:**
- Create:
  - `modules/umbriel/shell/Python.qml` (PanelWindow, bottom-right)
  - `modules/umbriel/shell/PythonSkin.qml` (the strip art)
  - `modules/umbriel/shell/PythonHead.qml` (head parts)
  - `modules/umbriel/shell/python-pose.js`
- Modify:
  - `modules/umbriel/shell/Palette.qml`: python roles, as in the mockup: `pyBody #5a6070`, `pyNet #1b1e24`, `pySaddle #717a8a`, `pyFleck #c7ccd4`, `pyBelly #8b94a3`, `pyOutline #0d0f12`, `pyEye #c7ccd4`, `pyShedEye #9fb4d6`.
  - `modules/umbriel/shell/Status.qml`: move its Row into a new `modules/umbriel/shell/StatusRow.qml` (an Item). Two layer windows on the same layer have no guaranteed stacking order, so the python's window hosts the status row itself, between its back and front coils. Status.qml then goes away.
  - `modules/umbriel/shell/shell.qml`: create Python per screen in Status's place.
- Test: `tests/python-pose-test.js`

**Interfaces:**
- Consumes: `Serpent.qml` and `serpent-spine.js`.
- Produces:
  - **`python-pose.js`:**
    - `coils(box: {x, y, w, h}, t: number, breath: number) -> {back: Point[][], front: Point[][], neck: Point[], tail: Point[]}`. Three stacked elliptical coils around `box` (the Status corner's rectangle in the python window's coordinates), radii scaled by `1 + 0.03 * breath`. Back halves and front halves are separate chains, so Status can sit between them.
    - `headPose(neckEnd: Sample, look: number, lift: number) -> {x, y, angle}`.
  - **`Python.qml`:**
    - `function lookAt(p: point)`
    - `function strikeAt(p: point, onHit: function)`
    - properties `night: bool`, `dilation: real` (0 = slit, 1 = wide), `jaw: real` (0 closed – 1 yawning), `dull: real`, `bulges: var`
    - Task 4 drives all of these.

- [ ] **Step 1: Write the failing tests.**
  - `test_python_pose_wraps_status_box`: for boxes at 3 sizes and 2 window sizes, every coil point lies outside the box, grown by `bodyWidth / 2`. Every coil's centre lies within the box's horizontal span.
  - `test_back_and_front_meet`: each coil's back chain ends where its front chain starts (within 0.5 px), so the seam is invisible.
  - `test_breath_changes_radius_only_slightly`: at breath 1 against breath −1, no point moves more than 4 px.
  - `test_head_rests_on_top_coil`: `headPose` with lift 0 puts the head within `bodyWidth` of the top coil's highest point, facing left (angle in 150°–210°).
- [ ] **Step 2:** Run `nix run nixpkgs#nodejs -- tests/python-pose-test.js`. Expected: FAIL.
- [ ] **Step 3: Implement `python-pose.js`.**
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Implement the art, drawn once, following the mockup's detail sheet** ("Heads" board) and the "Main" board.
  - **`PythonSkin`** is a strip about 1400 × 2·bodyWidth px, with bodyWidth = 22, holding:
    - overlapping scales (`PathQuad` scallops in rows, staggered);
    - the reticulated net (dark diamonds) with pale-edged saddles inside;
    - white flecks;
    - a belly band of plates along the lower 20% of v.
  - **`PythonHead`:**
    - wedge head with plates;
    - midline and eye stripes;
    - six heat pits per lip;
    - eyes: an iris disc with radial fibre lines, and a pupil Rectangle with `scale.x` driven by `dilation` (0.25 slit to 1 wide);
    - a catch-light;
    - nostrils;
    - a forked tongue: a Shape, shown and translated for flicks;
    - upper and lower jaws as separate Shapes hinged at the mouth corner, each with mouth lining and small teeth hidden inside.
- [ ] **Step 6: Implement `Python.qml`.**
  - The window is about 340 × 230, anchored bottom-right.
  - Input mask: the head plus coil bounds.
  - Draw order: back coils, then `StatusRow` (anchored where Status used to sit, bottom 14 / right 20), then front coils, the neck and the head. Front and back are two Serpent instances sharing the skin texture.
  - **FrameAnimation:**
    - breath: sine with a 5 s period;
    - `ripplePhase` advances 2.4 rad/s;
    - `rippleAmp` 0.06, plus a stronger wave every 6–10 s;
    - `sheen` 0.7;
    - tongue flick every 8–15 s;
    - gaze drift every 10–20 s.
  - StatusRow keeps its current look and contents. It is inside the input mask only if Status had handlers; check, and keep it click-through otherwise.
- [ ] **Step 7: Check in nested Umbriel.**
  - Screenshots at 3 moments: the coils around Status, sheen visible, head on the top coil.
  - `top`, 20 s idle: python alone ≤ 3%. Record it.
- [ ] **Step 8:** Commit with the message `umbriel: the python, coiled on the status corner`.

### Task 4: The python's behaviours

**Files:**
- Create: `modules/umbriel/shell/python-mood.js`
- Modify: `modules/umbriel/shell/Python.qml`, and `modules/umbriel/shell/Island.qml` (emit `noticeShown()` and `noticeGone(point at)`)
- Test: `tests/python-mood-test.js`

**Interfaces:**
- Consumes: Python's properties and functions from Task 3; Island's existing `view` / `item`.
- Produces (pure):
  - **`python-mood.js`:**
    - `isNight(date) -> bool`: 21:00–06:00, local time.
    - `nextYawn(now, rand) -> ms`: now + 25–45 min.
    - `huntState(state, pointer: {x, y, still: ms} | null, dt) -> {phase: "idle"|"coil"|"strike"|"recoil", target}`. "coil" at still ≥ 3000, "strike" at still ≥ 4000, then recoil for 600 ms. A pointer that moves (still resets) goes back from coil to idle.
    - `bulgeStep(bulges, dt) -> bulges`: each `u` moves 1/20 per s toward the tail and is removed at u > 1.
    - `addBulge(bulges) -> bulges`: capped at 3, the new one at u = 0.02.
    - `shedPlan(state, now, rand) -> {state, dull, eyes: "clear"|"milky", peel: 0..1, ghost: 0..1}`.
    - `parseShed(text) -> state`: a fresh schedule from now on garbage.
  - **Shed state file:** `~/.local/state/umbriel/python.json`, with `{"nextShed": <ms>, "phase": "none"|"dull"|"peel"|"after", "since": <ms>}`. Read and written with `FileView`; the directory is created on first write.

- [ ] **Step 1: Write the failing tests.**
  - `test_night_window`: 20:59 is false; 21:00, 03:00 and 05:59 are true; 06:00 is false.
  - `test_yawn_interval_in_range`: 200 rolls fall between 25 and 45 min.
  - `test_hunt_sequence`: still for 2.9 s is idle; at 3 s it's coil; at 4 s strike, then recoil, then idle after 600 ms.
  - `test_hunt_calms_when_pointer_moves`: coil with still reset to 0 goes back to idle.
  - `test_bulges_queue_and_cap_at_three`: four `addBulge` calls leave 3. After `bulgeStep` for 20 s total they're all gone, and a bulge added mid-swallow follows behind.
  - `test_shed_cycle`: a fresh state schedules within 7 days. At `nextShed` the phase is dull with milky eyes for 24 h, then peel 0→1 over 8 s, then the ghost fades over 60 s, then the next shed is ~7 days later.
  - `test_schedule_survives_time_jump`: `now` jumping forward 30 days gives one shed (not many), and the next shed lands ~7 days after that. A yawn whose due time is in the past fires once, not repeatedly.
  - `test_shed_state_garbage`: `parseShed("{nope")` returns a fresh schedule.
- [ ] **Step 2:** Run `nix run nixpkgs#nodejs -- tests/python-mood-test.js`. Expected: FAIL.
- [ ] **Step 3: Implement `python-mood.js`.**
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Wire it in `Python.qml`:**
  - **Notices.** `Island.noticeShown` makes the python look toward the island. On `noticeGone(at)`:
    1. A morsel spawns at `at`. It is a 5 px `bright` dot with a pre-blurred glow Image, in a small top-layer window of its own, or the island's window.
    2. It slides down the screen's right edge to the python over about 1.5 s with ease-in.
    3. The python strikes at it (`strikeAt`), then `addBulge`.

    Bulges feed `widths` via `widthAt`.
  - **Yawn:** `jaw` 0→1 over 0.6 s, hold 1.2 s, back to 0 with two 0.1 dips.
  - **Hunt:** from `huntState`, with the pointer read through a HoverHandler on the masked area.
  - **Night:** the head lowers (lift −1), motion speeds scale to 0.5, and `dilation` goes to 1. When the screen wakes from DPMS (outputs on), `dilation` narrows from 1 to 0.2 over 0.5 s.
  - **Shed:**
    - `dull` feeds the shader;
    - the eyes tint to `pyShedEye`;
    - the peel is a second Serpent with a pale, translucent skin whose visible span is u < 1 − peel, offset 3 px. It's then left as a ghost that fades.
- [ ] **Step 6: Debug check.** `UMBRIEL_SERPENT_DEBUG=1` shortens the yawn to every 20 s and the shed to 2 minutes, with the dull phase 20 s. In nested Umbriel:
  - send `notify-send hi` three times: three morsels, three bulges;
  - hover still near the head: coil, then strike;
  - wait for a yawn and a shed.

  Take screenshots of each.
- [ ] **Step 7:** Commit with the message `umbriel: the python eats notices, yawns, hunts and sheds`.

### Task 5: The viper and its venom

**Files:**
- Create:
  - `modules/umbriel/shell/HangingViper.qml`
  - `modules/umbriel/shell/HangingViperSkin.qml`
  - `modules/umbriel/shell/venom.js`
- Modify:
  - `modules/umbriel/shell/Island.qml`: host the viper under the pill, offset `+30 px` right of centre; the island window grows downward to fit about 140 px of body plus the fall area, input mask unchanged.
  - `modules/umbriel/shell/Palette.qml`: `venom` = `bright`; reuse the `viper*` roles.
- Test: `tests/venom-test.js`

**Interfaces:**
- Consumes:
  - `Serpent.qml`;
  - `UmbrielIpc.windows` (rectangles on the active workspace) and `UmbrielIpc.fullscreen`;
  - `Island.expanded`, and Island's `view !== "clock"` for "busy".
- Produces (pure):
  - **`venom.js`:**
    - `dripInterval(load: 0..1) -> ms`: 4000 at 0, 600 at 1, linear in between.
    - `parseLoad(prev, text) -> {load, sample}`: from two `/proc/stat` `cpu` lines. On garbage, `{load: 0, sample: null}`.
    - `dropStep(drop, dt, windows, fadeAt) -> drop`: phases `bead` → `thread` → `fall` → `splash` | `fade` → `gone`. Gravity is 1400 px/s².
    - `landing(x, y0, windows) -> number|null`: the y of the top edge of the topmost window whose x span contains x and whose top is below y0.

- [ ] **Step 1: Write the failing tests.**
  - `test_drip_interval_follows_load`: load 0 gives 4000, 1 gives 600, 0.5 gives 2300.
  - `test_load_from_proc_stat`: two real-format samples whose idle grows 50 of 100 ticks give load 0.5.
  - `test_load_parse_garbage`: `parseLoad(null, "")` gives load 0.
  - `test_landing_picks_window_below`: two overlapping windows; the topmost window whose span covers x and whose top is below the fang is chosen. With no window it returns null.
  - `test_drop_lifecycle`: a bead swells for 1.2 s, thread for 0.3 s, then falls. It lands at the window top in splash phase, then is gone after 0.8 s. With no window it fades by 300 px below the start.
  - `test_large_dt_is_clamped`: one `dropStep` with dt 5 s moves the drop at most as far as dt 0.05 would.
- [ ] **Step 2:** Run `nix run nixpkgs#nodejs -- tests/venom-test.js`. Expected: FAIL.
- [ ] **Step 3: Implement `venom.js`.**
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5: Implement the viper.**
  - **Skin:** a strip with keeled scales, blotches and the `viper*` palette, as on the mockup's side view.
  - **Head:** drawn once, as on the "Heads" board:
    - upper jaw tilted up 28°, lower jaw dropped 16°, both as hinged parts;
    - horns, eyes with slit pupils, pale mouth lining;
    - two fangs swung forward.
  - **Body:** a Serpent hanging in an S about 130 px long.
  - **Sway:** ±3° pendulum, plus a slow coil and uncoil (spine control points eased).
  - **Venom drops:** up to 4 Items, each a teardrop Shape with the `bright` fill plus a pre-blurred glow Image. Positions come from `dropStep`. The splash is a ring, two specks and a short trickle.
  - **Load:** `FileView` reads `/proc/stat` every 2 s.
  - **Retreat** (body pulled up behind the pill over 0.6 s) when `UmbrielIpc.fullscreen` or `Island.expanded` or the island isn't on the clock. Before retreating for fullscreen, show a hiss puff: two pale arcs, 300 ms. The viper returns 2 s after the cause ends.
  - **Spider:** it keeps dropping from the centre and never shares the viper's x.
- [ ] **Step 6: Check in nested Umbriel.**
  - Screenshots: the drop on its fang; a drop landing on a foot window's title bar; a drop fading over empty desktop.
  - Run `nix shell nixpkgs#stress-ng -c stress-ng --cpu 0 -t 15s`. Expected: the drip visibly quickens.
  - Fullscreen a window: the viper hisses and leaves; un-fullscreen it: it returns.
  - `top`, both serpents idle, 20 s: **≤ 4%**. Record it.
- [ ] **Step 7:** Commit with the message `umbriel: the viper drips venom from the island`.

### Task 4R: The raven (replaces Tasks 3–4's python)

The spec's "Revision" section is the authority. Tasks 3–4 (the python) are superseded: Task 3 was committed and Task 4 was abandoned (stashed).

**Files:**
- Delete:
  - `modules/umbriel/shell/Python.qml`, `PythonSkin.qml`, `PythonHead.qml`, `python-pose.js`, `StatusRow.qml`
  - `tests/python-pose-test.js`
  - the python palette roles
- Restore: `modules/umbriel/shell/Status.qml` as it was at 52e9ffc (`git show 52e9ffc:modules/umbriel/shell/Status.qml`), and its use in `shell.qml`.
- Create:
  - `modules/umbriel/shell/Raven.qml` (PanelWindow)
  - `modules/umbriel/shell/RavenBody.qml` (the parts, drawn once)
  - `modules/umbriel/shell/raven-mood.js`
- Modify:
  - `Island.qml`: emit `noticeShown()` and `noticeGone(point at)` (screen coords, bottom-centre). Only when a notice actually leaves, not when it's replaced in place.
  - `shell.qml`
  - `Palette.qml`: raven roles: `ravenBody #121419`, `ravenEdge #3a404b`, `ravenBeak #1b1e24`, `ravenEye #c7ccd4`, `ravenMembrane #8b94a3`, `trinket` = `bright`.
- Test: `tests/raven-mood-test.js`

**Interfaces (pure, `raven-mood.js`):**
- `isNight(date) -> bool`: 21:00–06:00, local time.
- `nextIdle(kind, now, rand) -> ms`. Kinds: blink 4–9 s, look 6–14 s, ruffle 2–4 min, preen 5–10 min.
- `watchState(state, pointer: {x, y, still: ms} | null, dt) -> {phase: "idle"|"watch"|"hop"|"peck"|"settle", target}`:
  - "watch" at still ≥ 2000;
  - "hop" at still ≥ 5000, then "peck" 300 ms, then "settle" 600 ms, then idle;
  - a moving pointer (still reset) goes from watch back to idle.
- `hoardAdd(hoard, now) -> hoard`: capped at 3, dropping the oldest.
- `hoardStep(hoard, now) -> hoard`: each item's opacity is `1 - age/600000`, removed at ≤ 0.
- `clamp dt` per clock rate, the same as the viper's.

- [ ] **Step 1: Write the failing tests:**
  - `test_night_window`: 20:59 is false; 21:00, 03:00 and 05:59 are true; 06:00 is false.
  - `test_idle_intervals_in_range`: 200 rolls per kind fall within that kind's range.
  - `test_watch_sequence`: still 1.9 s is idle; 2 s is watch; 5 s is hop, then peck, then settle, then idle.
  - `test_watch_calms_when_pointer_moves`
  - `test_hoard_caps_at_three_and_fades`: four adds leave 3, the oldest dropped; after 10 min all are gone; a past-due step removes once and doesn't throw.
- [ ] **Step 2:** Run `nix run nixpkgs#nodejs -- tests/raven-mood-test.js`. Expected: FAIL.
- [ ] **Step 3: Implement `raven-mood.js`.** Run again. Expected: PASS.
- [ ] **Step 4: Remove the python and restore Status** (files above). Run `nix build` of the toplevel. Expected: it builds, and `grep -r Python modules/umbriel` finds nothing.
- [ ] **Step 5: Implement `RavenBody.qml`.** The parts are Shapes (CurveRenderer), drawn once. Each part is an Item with its pivot at its joint:
  - layered scalloped feathers;
  - the iridescent overlay (a pre-drawn gradient Shape, clipped to wing and back, with opacity 0.10–0.22 drifting);
  - beak upper and lower hinged at the gape;
  - hackles that scale on a caw;
  - an eye with a catch-light;
  - the membrane, which slides across for blinks;
  - legs and toes gripping a y-line.

  Leave the plan with screenshots of rest, caw, preen, sleep and hop.
- [ ] **Step 6: Implement `Raven.qml`:**
  - the window, the mask, the multi-rate clock, and the behaviours from the spec;
  - the trinket in its own small top-layer window, existing only while in flight;
  - debug: `UMBRIEL_RAVEN_DEBUG=1` makes ruffle and preen every 20 s and treats every hour as night for 30 s every 2 minutes.
- [ ] **Step 7: Check in nested Umbriel:**
  - `notify-send hi` ×3 gives three caws and three trinkets in the hoard;
  - a still pointer gives watch, then hop and peck;
  - screenshots of each;
  - `top` idle 20 s: the raven's delta is ≤ 1%, and the whole shell is ≤ 4%. Record both.
- [ ] **Step 8:** Commit with the message `umbriel: a raven and its hoard replace the python`.

### Task 5D: Detail pass on the viper and the raven

The user asked to "go much more detailed on the viper and the raven". The approved art is the canvas boards **ViperDetail** and **RavenDetail** (sources `serpents/project/ViperDetail.dc.html` and `RavenDetail.dc.html` in the session scratchpad). Detail drawn once is free at runtime, so add as much as reads well at 1×.

**Files:**
- Modify: `HangingViper.qml`, `HangingViperSkin.qml`, `RavenBody.qml`, `Raven.qml` (only where a pose needs new parts).
- Optional: shader tweaks in `serpent.frag` for the keeled-scale highlight.

**Viper**, per the ViperDetail board:
- keeled dorsal scales with a light ridge, and blotches with pale edging, in the skin strip;
- ventral plates on the underside where the S turns (the belly band in the strip);
- labial scales along the lips, a heat pit, a brow ridge and supraocular horn scales;
- an eye with a vertical slit pupil and a catch-light;
- pale mouth lining with the glottis and tongue sheath;
- sabre fangs with translucent tips and a venom groove;
- a venom bead with an internal highlight and a dark refraction band;
- on pale wallpapers, a 2 px outline, a soft shadow and a slate rim on the venom;
- a forked tongue flick every 10–20 s. The tongue is a once-drawn part, translated and scaled, at the display's rate only during the ~250 ms flick.

**Raven**, per the RavenDetail board:
- a heavy beak with the culmen ridge, nasal bristles and the gape line;
- shaggy throat hackles;
- the nictitating membrane;
- layered feathers: crown, nape, mantle, scapulars, coverts, and primaries with barb lines;
- a wedge-shaped tail;
- scaled legs with scutes and curved claws gripping the row;
- the blue-violet-green iridescence on the wing and mantle;
- a slate edge (#3a404b) on every feather.

Improve the preen pose: the board's weakest thumbnail.

**Constraints:**
- Colours stay properties of RavenBody, because niri reuses it (Task 4N).
- No new per-frame cost. Measure the shell's idle CPU before and after; the delta must be within noise.

**Steps:**
- [ ] **Step 1: Viper art.** Take screenshots at 1× and zoomed, on dark and pale wallpapers, and compare them by eye with ViperDetail. Iterate.
- [ ] **Step 2: Raven art.** Take screenshots of rest, caw, preen, sleep, hop and hoard at 1× and zoomed, and compare with RavenDetail. Iterate.
- [ ] **Step 3: Measure.** Expected: all tests pass, the build succeeds, and the CPU delta is within noise.
- [ ] **Step 4: Commit** with the message `umbriel: detailed viper and raven art`.

### Task 4N: The raven on niri too (replaces the niri python)

The user: "we're removing the python for the raven on both fronts". On niri the koi stay the default mascot. `RICE_MASCOT=raven` replaces `RICE_MASCOT=python`.

**Files:**
- Delete:
  - `modules/shell/Python.qml`, `modules/shell/python-geometry.js`, `tests/python-geometry-test.js`
  - the unused `[templates.python]` in `modules/theme/matugen.toml` and `modules/theme/templates/python.svg` (fastfetch uses the koi)
- Keep: starship's `$python` module (it's the language, not the mascot).
- Modify:
  - `modules/shell/BottomBar.qml`:
    - drop the python Loaders, restGap/leftPad/gap special cases and the extra height;
    - add `RICE_MASCOT=raven`: a Loader hosting a niri `Raven` perched on the bar pill's top edge at the right end, about 44 px tall;
    - the koi pond stays hidden when the raven is chosen, as it was for the python;
    - `notice(x)` makes the raven turn its head toward x and caw instead of the python's flinch.
  - `modules/shell/Toggles.qml` comment.
  - `docs/RICE.md`: the python paragraph becomes a raven paragraph; update the tests list and file map.
  - Share `RavenBody.qml` and `raven-mood.js` with Umbriel. Deploy the same files into both Quickshell configs from one source, e.g. `modules/shell/raven/` copied into the umbriel-shell derivation, or a symlinked source; pick the simpler.
- **Colours:** RavenBody takes its colours as properties. Umbriel passes the slate roles. Niri passes the matugen `Theme` colours (body = a very dark surface, edge = outline, eye = onSurface, sheen = primary/tertiary at low opacity).
- **Clock:** the same multi-rate clock, running only while the bar is shown (`root.shown`).
- **Behaviours on niri:** idle life (breath, blink, look, ruffle, preen), watching a still pointer on the bar, caws on `notice(x)`, and sleep after dark. No hoard; niri's notifications live elsewhere.
- **Tests:** `tests/raven-mood-test.js` covers the shared maths. `bash tests/config-test.sh` passes (update any test that greps for the python). `grep -rni 'python' modules/shell` finds nothing.
- [ ] **Steps:**
  1. Remove the python and the matugen template, then build.
  2. Add the raven Loader and colours.
  3. Take a screenshot of the niri bar with `RICE_MASCOT=raven` (run a scratch `qs -p` copy on the Overlay layer; never kill `qs -c rice`).
  4. Measure CPU with the bar shown: it's below the koi's.
  5. Commit with the message `rice: a raven replaces the python mascot`.

### Task 6: Docs and final checks

**Files:**
- Modify: `README.md` (the Umbriel section), `docs/superpowers/specs/2026-11-07-umbriel-serpents-design.md` (only if a ruling changed something)

- [ ] **Step 1:** Run all tests: `for t in tests/*-test.js; do nix run nixpkgs#nodejs -- $t; done` and `for t in tests/*-test.sh; do bash $t; done`. Expected: all pass.
- [ ] **Step 2:** Run `niri validate` and the full toplevel build. Expected: both pass.
- [ ] **Step 3: Update the README's Umbriel section** to cover:
  - the two serpents and what each one does;
  - `UMBRIEL_SERPENT_FPS` and `UMBRIEL_SERPENT_DEBUG`;
  - the measured CPU figures;
  - the shed state file.
- [ ] **Step 4:** Commit with the message `umbriel: serpents in the README`.
