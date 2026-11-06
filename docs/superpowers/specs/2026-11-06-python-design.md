# The python: a reticulated python coiled around the bottom bar

Date: 2026-11-06
Status: approved in conversation, awaiting doc review

## Why

The niri rice's mascot is a small curled **cobra** (hood, upright pose) in the auto-hide bottom bar (`modules/shell/Cobra.qml`, art in `modules/shell/assets/`), plus a matching fastfetch logo rendered from `modules/theme/templates/cobra.svg`. The user finds it "kinda basic". They want a real python, and they want it **coiling around the actual status bar**, not sitting inside it.

## What the user decided

- **Species: reticulated python.** It's recognisable by the net-like pattern of irregular dark-outlined diamonds with smaller light-centred markings between them, the gold-yellow tones and the long head with a thin dark line down the crown. Reference photos were viewed together, sourced from Wikipedia/Wikimedia Commons ("Reticulated python" article).
- **Pose: spiral wrap.** The body coils around the bottom bar pill about three times like a constrictor, passing alternately in front of and behind the pill. The tail starts off the left end, and the head rises off the right end above the bar.
  - The approved mockup is `.superpowers/brainstorm/*/content/python-pose.html`, option C (not committed; the description here is the spec).
- **Colour: dark python with wallpaper accents.**
  - The base and outlines stay near-black (`surface` / `surfaceContainer`).
  - The saddle patches use the wallpaper's dark accent (`primaryContainer`).
  - The flecks between saddles, and the eyes, use `tertiary`.
  - The head uses `secondary`.
  - It recolours with every `rice-wall` change, like everything else, but keeps a real python's contrast.
  - Mockup: `python-colour.html`, option C.

## Agreed behaviour (proposed by Claude, accepted by the user)

- **Coils sit in the gaps.** The front-passing coils cross the bar only in the gaps between widget groups (left end · workspaces | toggles | clock · power), never over a widget. The bar gets a little wider to make room.
- **Animation:**
  - **Breathing:** the coils tighten and loosen very slightly, every 4–6 s.
  - **Sliding:** every 20–40 s the pattern creeps along the body for a second, as if the snake were shifting its grip.
  - **Tongue:** a flick every 8–15 s, like the cobra today.
  - **Hover tracking:** the head turns towards whatever bar widget the pointer is over.
- **Freezes while the bar is hidden.** Everything stops while the bar is hidden, like `Cobra.qml` does now, to save CPU.
- **Moves with the bar.** The python slides up and down with the bar. The bar's layer surface and its hover/input region grow just enough to contain the coils above and below the pill. The pill's own 38 px height (`Theme.barHeight`) doesn't change.
- **Body thickness: about 40% of the pill's height**, roughly 15 px at the real 38 px bar. This follows the proportions of the approved mockup, where the body is a 15-unit stroke around a 38-unit pill. *My call:* I earlier wrote "about the bar's height", but the mockup is what the user looked at and picked, and a body as thick as the bar would read as a sleeve, not a constrictor. The coils must not make the pill itself bigger.
- **Raise the pill to make room.** The pill sits 8 px above the screen edge today, which leaves no room for the lower loops. *My call:* raise the pill's resting position by about the body thickness, to roughly 24 px from the bottom edge, so the lower arcs show fully. Adjust the hide/slide distance and the input/hover region to match. The 3 px reveal strip at the screen edge stays as it is.
- **Back coils never show through the pill.** The pill is translucent (`Qt.alpha(Theme.surface, 0.82)`). *My call:* mask the back coils out wherever the pill covers them, so nothing shows faintly under the dots or text, while the pill keeps its current translucent look.
- **Fastfetch logo:** a still image of the same python coiled into a ball (the defensive ball-python pose: tight coils, head tucked in), coloured the same way. It replaces `cobra.svg`/`cobra.png` in the matugen templates and `fastfetch.jsonc`.

## Goals

- It looks like a reticulated python at a glance, not a generic snake. The net-like pattern and the wedge head are the tells.
- It's still recognisably part of this rice: wallpaper-tinted and dark.
- It's cheap. With the bar hidden for 60 s, `qs -c rice` averages under 1% CPU, the same bar as Task 7 of the niri plan. Animation ticks stay slow (the existing 25 fps single-timer approach is fine).

## Non-goals and anti-goals

- No hood and no upright cobra pose anywhere.
- Never covers a workspace dot, toggle, clock digit or the power button. It's a failure if it hides information or blocks clicks on the bar.
- No cartoon face or big eyes.
- Not a separate window or overlay that stays when the bar hides.

## Constraints

- **Stack:** Quickshell 0.3.2 QML in `modules/shell/` (deployed to `~/.config/quickshell/rice` by `modules/shell/default.nix`, whose filter only ships `.qml` and `.svg`). Colours come from `Theme.qml`, which reads `~/.cache/rice/colors.json` written by matugen.
- **Passing behind the pill** needs the back segments drawn under the pill and the front segments over it. That means at least two layers, or masking, inside `BottomBar.qml`.
- **Testing:** `qmllint` clean (warnings OK), `qs -p modules/shell` shows no QML errors in `qs log`, and `nix build …toplevel` succeeds.
- **Delete** `Cobra.qml` and the cobra SVGs once the python replaces them. Update the README's mention of the cobra.

## Left to the builder

- How the body is drawn: SVG paths, a QML `Shape` with a stroked path and a pattern, or a shader. The choice is free as long as the reticulated pattern reads at about 15 px body thickness and the CPU budget holds. The mockup's layered dashed strokes (base, saddles, flecks, highlight) are a proven starting point.
- Which gaps get the front crossings, and how the coils adapt when the toggles change width.
- Whether the python appears on every monitor.
- The exact coil geometry and how it adapts to the bar's width as widgets change.
- The fastfetch logo's exact composition.
