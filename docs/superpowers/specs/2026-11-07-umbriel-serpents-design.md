# Umbriel serpents: a python in the corner, a viper dripping from the island

Approved mockups: the "Umbriel serpents" design canvas (https://claude.ai/artifact/3eLTY6EuH1NriYhjhJmUTF), all five boards. The user's words: "pair this with full understanding of animating at decent frames … give it great details, make it beautiful". Their PC can take the cost, but the animation must be smooth.

## What the user decided

- **Two serpents on the Umbriel desktop, as on the Overview board.**
  - A **reticulated python** coiled around the **bottom-right status corner**: three stacked coils, with the head resting on the top coil and watching the screen. This is placement A on the "Where the python lives" board.
  - A **viper hanging from under the island**, head down, jaws open, **venom dripping from its fangs**. This is hang A on the "dripping viper" board.
- **Go all out on detail**, as on the detail sheet:
  - **Python skin:** overlapping scales under the reticulated net, pale-edged saddles, flecks, and belly plates where a coil turns.
  - **Python head:** large plates, heat pits along both lips, pale irises with slit pupils, and a forked tongue.
  - **Viper:** horns over the eyes, keeled scales and blotches, hinged fangs, and a glowing venom bead.
- **Every behaviour on the storyboard:**
  - **The python** eats notifications, yawns, hunts the pointer, ripples along its coils, sheds once a week, and sleeps after dark.
  - **The viper** drips faster under CPU load and pulls up into the island for fullscreen windows.
- **Colour:**
  - The Umbriel slate palette everywhere.
  - The python's **iridescent sheen is the only colour on the desktop**.
  - The venom is the palette's one bright accent (`bright`), always with a glow.
  - During a shed, the python's milky eyes are the only blue.

## How it moves: smooth at any refresh rate (my call; the user asked for it)

The niri python was expensive because it rebuilt geometry on the CPU every tick. Here, nothing is rebuilt per frame.

- **Skin drawn once.** Each serpent's body skin is painted **once** into a straight horizontal texture strip, at 2× resolution:
  - u runs along the body, v across it;
  - the strip holds the scales, net, saddles, flecks, the belly band and the outline.

  It is drawn with QtQuick Shapes inside a hidden `ShaderEffectSource` (`live: false` after the first frame). The palette is fixed, so it is never redrawn, except for the shed state, which swaps in a second, pre-drawn strip.
- **Bending on the GPU.** A `ShaderEffect` with a `GridMesh` (about 128 × 4) bends the strip along the spine. The vertex shader gets the spine as a uniform array of control points: position, tangent and width scale, about 24 to 32 points. It interpolates them per vertex with Catmull-Rom. Per frame, only the uniforms change.
- **Lighting in the fragment shader:**
  - rounded body shading across v;
  - a specular line;
  - the iridescent sheen: a thin-film hue from the angle between the body tangent and a fixed light, drifting with time;
  - travelling muscle ripples, as brightness and width modulation along u;
  - the shed's dullness and peel.
- **Shadow:** a second pass over the same mesh, black with a soft v falloff and an offset. No blur effect.
- **Heads, jaws, eyes, tongue, horns, fangs and drops** are separate small items, each drawn **once**. They move only by transform: position, rotation, scale and opacity. Pupil dilation is a scale. Yawns and open jaws are rotations about a hinge.
- **The clock** is a `FrameAnimation`, which runs at the display's refresh rate, 144 Hz here. All motion is **delta-time based**, so it is equally smooth on any display.
  - It runs only while something is visible and not paused: no fullscreen window, not locked, outputs on. The pause signals are the same ones as Task 3's wallpaper (`paused`) and `UmbrielIpc.fullscreen`.
  - `UMBRIEL_SERPENT_FPS=<n>` can cap it, for testing or to save power.
- **Budget.** Measure `qs -c umbriel` with both serpents idle on screen. The target is **≤ 4% of a core at 144 Hz**. If it's over that, the spine maths gets optimised before any detail is cut.

## The python (bottom-right)

- **Window.** The python gets its own `PanelWindow`, bottom-right, about 320 × 220. The Status corner sits inside the coils.
  - It's click-through except for its body and head (an input mask). The mask lets it see the pointer for hunting while staying out of the way.
  - It hides on fullscreen, like Status.
- **Pose.** Three stacked elliptical coils, back halves drawn before Status and front halves after it. The neck rises from the top coil, and the head rests on that coil facing left.
- **Always alive:**
  - breathing, a slow swell of the coils every about 5 s;
  - muscle waves along the coils every few seconds, with the sheen moving with the wave;
  - a tongue flick every 8–15 s;
  - the head drifting its gaze now and then.
- **Eats notifications.** When the island shows a notice:
  1. The python lifts its head and looks toward the island.
  2. When the notice leaves the island, a small pale **morsel** (a glowing mote) drops from the island. It slides down the right edge of the screen to the python, which **strikes** and swallows it.
  3. A **bulge** then travels down the body over about 20 s.

  Several notices queue as several bulges, with at most 3 visible.
- **Yawns** every 25–45 min: the jaw unhinges almost flat (lower jaw rotates down, upper jaw up) and shows the pale mouth lining and small teeth. It holds about 1.2 s, then closes with two small chewing shifts.
- **Hunts the pointer.**
  1. If the pointer rests within its reach (its window) for 3 s, it draws its neck back into an S, flicking its tongue.
  2. If the pointer stays still another 1 s, it **strikes** toward the pointer over about 120 ms, then recoils over about 600 ms.
  3. Moving the pointer during the S calms it back down.
- **After dark (21:00–06:00):**
  - the head lowers flat onto the coil;
  - motion slows to about half;
  - the pupils dilate to wide ovals with a faint glint.

  At dawn the pupils narrow again, and they also narrow when the screen wakes from DPMS.
- **Sheds once a week**, on a schedule stored in `~/.local/state/umbriel/python.json`:
  1. For a day the skin dulls and the eyes go milky blue.
  2. Then, at a random moment while the screen is on, a pale ghost skin peels from the nose back over about 8 s.
  3. The ghost lingers, fading over a minute, and the colours return slightly brighter for the rest of the day.

## The viper (top, under the island)

- **Window.** The viper hangs in the island's window (or its own top layer window), from the pill's underside, offset right of centre so the spider (Task 7) still drops from the centre.
- **Pose.**
  - The body comes out from behind the island and falls in a slow S, about 130 px long, head down.
  - The jaws are open, with the upper jaw tilted up, the lower dropped, and both fangs swung forward.
  - It sways gently (±3° and a little pendulum drift), and its body slowly coils and uncoils a little.
- **Venom.**
  1. A bead forms on the forward fang tip and swells.
  2. It necks into a thread, snaps and falls with gravity, leaving a faint streak.
  3. It lands on the **top edge of the topmost window beneath it** (from `UmbrielIpc.windows`) as a splash: a ring, two specks, and a short trickle that fades.
  4. If no window is below, it fades out about 300 px down, with a faint ring.

  Drops glow, and the glow is a pre-blurred image.
- **Drip rate follows CPU load**, read from `/proc/stat` every 2 s: one drop every about 4 s when calm, down to one every about 0.6 s at full load. This is what the user called "a heartbeat you can read".
- **Retreats:**
  - for a fullscreen window: a visual hiss puff, then it pulls up behind the island over about 0.6 s, and comes back down 2 s after fullscreen ends;
  - while the island is expanded (launcher, notice, music, OSD), so it never fights the island's morph.

## Non-goals and anti-goals

- No sound.
- No colour beyond the sheen, the shed's blue eyes, and the venom's bright glow.
- The serpents never cover a focused window's content. The python stays in its corner; the viper's drops only land on title-bar edges and fade.
- Nothing runs while the serpents are hidden.
- The niri desktop is untouched. This is Umbriel only.

## Left to the builder

- The exact skin art: within the detail sheet's look.
- Spine maths and how the poses are parameterised.
- The shader code.
- The mesh resolution, if the budget needs it.
- The exact timing curves.

## Revision (2026-11-07, morning): a raven replaces the python

The user had second thoughts about the python and chose a **raven** for the bottom-right status corner instead. The viper, the venom and the GPU body are unchanged. Everything in "The python (bottom-right)" above is superseded by this section. The python's code (Python.qml, PythonSkin.qml, PythonHead.qml, python-pose.js and its test) is removed, and Status goes back to a plain corner window that the raven perches beside.

- **Look.** A slate raven, about 64 px tall, perched on the top edge of the status row, facing left toward the screen.
  - It is drawn **once** as layered parts, the same way the python's head was: body, folded wing, tail fan, legs gripping the row's edge, head, upper and lower beak (hinged), throat hackles, eye and nictitating membrane.
  - Feathers are shapes with overlapping scalloped edges: wing coverts, primaries and tail feathers.
  - The **only colour** is the raven's real iridescence: a faint blue-violet-green sheen on the wing and back. It's a pre-drawn overlay whose opacity and offset drift slowly. This replaces the python's sheen as "the only colour on the desktop".
  - The palette is the Umbriel slate roles: near-black body, a slate edge highlight, a pale eye catch-light.
- **How it moves.** No geometry is rebuilt, ever. Every part moves by transform (rotation about its joint, translate, scale, opacity). The clock is the multi-rate one from the viper:
  - an idle tick at 10 Hz;
  - 30 Hz for head turns;
  - the display's rate only during a hop, a caw or a wing flap.
  - It pauses when hidden, on fullscreen, when locked and when outputs are off.
- **Always alive:**
  - breathing, a 1.5% chest swell every ~4 s;
  - a blink with the pale nictitating membrane every 4–9 s;
  - a head tilt or turn every 6–14 s, sometimes a quick double-take;
  - a feather ruffle, with the body puffed 6% and settled, every 2–4 min;
  - a preen, beak tucked into the wing for ~2 s, every 5–10 min.
- **Notifications, the hoard.**
  1. When the island shows a notice, the raven snaps its head toward the island and **caws**: beak open, hackles puffed, two small pale arcs from the beak, in silence.
  2. When the notice leaves, a small glinting **trinket** (a pale ring or coin with a glint, glow pre-blurred) drops from the island down the right edge.
  3. The raven hops to meet it, catches it in its beak and sets it on the status row behind it.
  4. Up to **3 trinkets** sit in its hoard. Each fades over ~10 minutes, oldest first.
- **The pointer.** If the pointer rests near the raven (within its window) for 2 s, it cocks its head to watch it, tracking it with the eye. If the pointer stays still another 3 s, it hops once toward it and pecks the air. Moving the pointer away makes it lose interest.
- **After dark (21:00–06:00):** it fluffs up 8% and tucks its head under its wing to sleep. Only the slow breathing moves. A notice wakes it for the caw, then it settles back after ~20 s.
- **Window.** A bottom-right `PanelWindow` of about 180 × 120, beside and above the status row. It's click-through except for the raven's body (the input mask), so it can see the pointer, and it hides on fullscreen like Status.
- **Budget.** Idle, it adds **≤ 1%** to `qs -c umbriel`, and the whole shell with the raven and the viper stays ≤ 4%.
