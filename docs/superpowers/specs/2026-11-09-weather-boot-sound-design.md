# Live weather, themed boot and login, sound design

The user picked these from a list ("1,2,3"). There are no mockups. Every call below is mine, and the user reviews them after they're built.

## 1. Real weather drives the scene
- **Source:** Open-Meteo (`api.open-meteo.com/v1/forecast?current=weather_code,precipitation,rain,cloud_cover,wind_speed_10m,is_day`). It needs no API key.
  - The location comes from `RICE_WEATHER_LAT` / `RICE_WEATHER_LON`. The default is Nairobi (-1.29, 36.82): the machine's timezone is Africa/Nairobi.
  - A `rice-weather` script fetches with curl every 20 minutes through a systemd user timer. It writes `$XDG_RUNTIME_DIR/rice/weather.json` (or the existing state dir convention) holding `{kind: clear|cloudy|fog|drizzle|rain|storm|snow, intensity: 0..1, wind: 0..1, isDay, updated}`.
  - The mapping from weather codes is pure and unit tested.
  - When it's offline, keep the last file. If the file is older than 3 h, both shells fall back to their current behaviour.
- **Umbriel:** the rain and storm wallpaper effects already exist ("live: rain/storm"). Their intensity follows the weather:
  - drizzle is light, rain is medium, storm is heavy with wind slant;
  - clear or cloudy means a light mist only, or whatever the shader's lowest setting is.

  Read the file on a slow Timer (60 s), and ease uniform changes over about 10 s.
- **niri:** the koi pond gets raindrop ripples on the water when it rains, scaled by intensity, plus a soft fog tint for fog.
  - Use the existing capped clocks. There must be no new always-on frame loop, and the idle cost must not rise.
  - On a clear day nothing changes.
- **Debug:** `RICE_WEATHER=storm` (etc.) forces a kind in both shells.

## 2. Themed boot and login
- **Plymouth:**
  - `boot.plymouth.enable` with a custom theme in `modules/boot/`: a dark pond, a koi circling slowly as the spinner, and the raven perched, matching the rice palette. The colours are fixed, since matugen isn't available at boot: use the default dark purple-blue rice tones.
  - Quiet boot: `boot.initrd.systemd.enable`, `quiet`, `splash` and `loglevel=3`. Plymouth must fall back gracefully, so the LUKS password prompt (if any) still works.
- **Login (SDDM, already a custom video theme in `modules/sddm`):**
  - Restyle the login card in pond glass: a translucent panel, a lit top rim and static drips under the card, using the same glass language as the bar and rofi.
  - Keep the video background and every working function: user, password, session choice and power.
  - Use a fixed palette, or read the last matugen colours only if they're copied to a world-readable path.
- **Safety:** the toplevel must build, and SDDM must load the theme. Test it with `sddm-greeter-qt6 --test-mode --theme <path>`, which runs in a window, and take a screenshot. The login must never be lost: if the theme errors, SDDM shows its fallback.

## 3. Sound design
- **Sounds:** short, soft and original, under 0.4 s. Generate them with sox at build time or commit them as small .oga files.
  - a water drop for normal notifications;
  - a low caw for critical ones;
  - a soft ripple tick for volume changes, at most one per 150 ms.
- **Playback:** `pw-play` at a modest volume. Both shells play the notification sounds; the niri OSD plays the volume tick.
- **Off switch:** `RICE_SOUNDS=0` turns them off. They're also muted during the night shift (`isNight` from `raven-mood.js`) and while the default sink is muted. Do Not Disturb, if the shell has it, mutes them too.
- **Cost:** none while idle; one short process per sound.

## Non-goals
- No new always-on frame loops.
- No paid or keyed APIs.
- No change to how the user logs in or unlocks: the same SDDM, user and password flow.
