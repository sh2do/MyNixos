# Niri UI revisions: living media pill, pond-glass bar, grouped notices, glassy dripping menus

Approved mockups: the "Umbriel serpents" design canvas (https://claude.ai/artifact/3eLTY6EuH1NriYhjhJmUTF), boards **NiriTop**, **NiriBottom**, **NiriNotify** and **NiriMenus**. Their sources are in the session scratchpad at `serpents/project/Niri*.dc.html`. The user picked option **A** on the first three boards. For the menus they said: "kind of keep the design as is but make it more glassy, or hell, even add drip like it came from water, not animated".

This is the niri session only (`modules/shell`, `modules/rofi`). Umbriel is untouched.

## What the user decided

### Top pill: A, the living media pill
- **While music plays**, the pill grows to 40 px tall and shows:
  - the album art (28 px, rounded 8), with a soft glow behind the pill in the art's dominant colour;
  - title and artist on two lines;
  - a 5-bar mini visualiser;
  - a 2 px progress line inside the pill's bottom rim.

  Hovering swaps in previous, play/pause and next.
- **Otherwise** it stays as it is: the focused window's title, with the same drop-in and tuck-away behaviour.
- **Fullscreen** still hides it.

### Bottom bar: A, pond glass
- The bar is 42 px tall, with a highlight along its top rim and more glass depth: a faint inner gradient and a reflection band. The koi still swim under the glass.
- The widget groups sit on three faint "stones": rounded, slightly lighter patches.
- "On" toggles show a lit icon plus a 3 px dot.
- The active workspace is a glowing capsule.
- When hidden, a visible 120 × 2 px "water line" sits centred at the screen edge, replacing the invisible 3 px strip. Touching the edge still raises the bar.

### Notifications and OSD: A
- **Notifications** are grouped into one card per app:
  - the app icon, name, count and age;
  - real action buttons from the notification's actions (e.g. "Reply", "Mark read");
  - older messages from the same app peeking underneath as a stack;
  - a 3 px progress line for the timeout.

  Critical notifications still stay until clicked.
- **The OSD** (volume, brightness) becomes a 56 × 168 water-level capsule. Its fill has a wavy surface, and each change sends a ripple across it.

### Menus: the current design, glassier and dripping
- The rofi layout stays as it is: the same structure, rows and wallpaper panel.
- **More glassy:**
  - a translucent matugen surface;
  - a highlight along the top rim and a faint inner gradient;
  - real background blur, if niri 26.04 supports it for rofi's layer surface; otherwise translucency alone.
- **Drips:** static water drips hang from the bottom edge of the menu window (and from the selected row's lower edge, if rofi allows), as though the glass had just come out of water. They are **not animated**. They are a matugen-coloured image, so they follow the wallpaper like the koi logo does.
- All `rice-menu` menus share it: apps, wifi, bluetooth, audio, profile, power, clipboard and wallpaper.

### The raven on niri
The raven replaces the python (the serpents plan's Task 4N). With option A's pond glass it perches on the bar's top rim at the right end.

## How it's built (my calls)
- Everything follows matugen through `Theme.qml` and the rofi colours, as today.
- **Dominant colour of the album art:** sample it once per track. Draw the art scaled down to a few pixels in a hidden ShaderEffectSource, then read it with `grabToImage`. If that's awkward, use the matugen `primary`. No per-frame work.
- **Visualiser:** `cava` in raw output mode, through a Process, at ≤ 30 Hz, only while music plays and the pill is shown. If cava isn't available, show a gentle fake pulse driven by the playback position.
- **The water OSD:** a ShaderEffect or a Shape for the wavy surface. It animates only while the OSD is visible, on its own clock at ≤ 60 Hz.
- **Drips:** a matugen template SVG rendered to PNG (`rsvg-convert`), used as a rofi `background-image` on the window's bottom area, or on a child widget sized to the drip strip.

## Budget
- The bar shown and idle must not cost more than it does today: koi at about 15%.
- The top pill with music playing: ≤ 2% extra.
- The OSD visible: ≤ 3% while it shows.
- The menus have no runtime cost.

## Non-goals
- No change to Umbriel.
- No new daemons except cava, while music plays.
- No animated drips.
