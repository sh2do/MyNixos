# Night shift, pond-glass wallpaper picker, phone link

The user picked these from a list of ideas ("4, 3, work on those … also add a way of linking to my phone if possible like sending alerts and stuff") and left me to build them. No mockups; every call below is mine, and the user reviews them on return.

## 1. Pond-glass wallpaper picker (niri)
- `modules/shell/WallpaperPicker.qml`, the carousel that slides up on Mod+Ctrl+W, gets the same glass language as the pond-glass bar and the rofi menus:
  - a translucent matugen surface with a lit top rim;
  - an inner gradient and a reflection band;
  - each card on a faint stone;
  - the selected card with a glowing rim and static water drips along its bottom edge, reusing `~/.cache/rice/drips.png` or the drip-row art from the rofi theme;
  - a short rise and settle as the selection moves.
- The behaviour is unchanged: same keys, same rice-wall calls.
- No always-on animation; it costs nothing while closed.

## 2. Night shift, both desktops (21:00–06:00, the raven's `isNight`)
- **One clock.** Both shells read `isNight` from `raven-mood.js`, the same source the ravens use, so everything changes together. A `RICE_NIGHT=1` / `UMBRIEL_NIGHT=1` debug override forces night.
- **niri:**
  - **Colours:** `Theme.qml` gains a `night` factor (0→1 over ~2 minutes at the change, never per frame). The shell's surfaces dim by ~12% and cool slightly, mixing toward the matugen surface-dim tone, and text keeps its contrast. This affects only the Quickshell UI (bar, pill, cards, OSD, picker), not the screen gamma.
  - **Koi:** at night they slow to a drift and gather under the lily pad, with less wandering and fewer surface rises. Music still wakes them a little, as the music reaction does.
  - **Raven mode:** it already sleeps at night.
- **Umbriel:**
  - **Colours:** `Palette.qml` gains the same dim/cool night factor for the shell's chrome (chain links, island, status).
  - **The hanging viper:** it coils up shorter (hangs ~30% higher), sways at half speed and drips at half the rate. Its eye dims.
  - **The raven:** it already sleeps.
  - **The rain:** the mist on the wallpaper deepens slightly, if Background exposes a mist level.
- **Cost:** no new always-on work. The factor is checked on the existing slow timers.

## 3. Phone link (KDE Connect)
- **Why KDE Connect:** it's an open protocol over the LAN, so there's no cloud service. The phone shows desktop alerts, and phone notifications appear as desktop notifications. It has battery, ring-my-phone, file sharing and clipboard. The phone side is the KDE Connect app (Android; iOS support is limited).
- **System:** `programs.kdeconnect.enable = true` (opens TCP/UDP 1714–1764 in the firewall). Autostart its daemon in both the niri and Umbriel sessions.
- **Phone → desktop:** phone notifications arrive through the desktop notification server, so they show as the new grouped cards on niri and in the island on Umbriel.
- **Desktop → phone:**
  - a `phone-alert "<message>"` script pings the phone with a message, e.g. `nh os switch; phone-alert "switch done"`;
  - a `phone-alert --critical` mode, plus a niri bar option `RICE_PHONE_FORWARD=critical` (default on), forwards **critical** desktop notifications to the phone. Ordinary ones are not forwarded.
- **The bar:**
  - **niri:** a small phone chip in the pond-glass bar shows the paired phone's battery and whether it's connected. Click to ring the phone; right-click to send a file. It's hidden when no phone is paired.
  - **Umbriel:** a phone glyph and battery in the status corner, hidden when no phone is paired.
- **Pairing** needs the user: install KDE Connect on the phone, be on the same Wi-Fi, then pair with `kdeconnect-app` or `kdeconnect-cli --pair`. The README gets the steps.
