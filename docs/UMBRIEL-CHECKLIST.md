# Umbriel: first-login checklist

These checks need a real Umbriel login, which can't be tested from inside a niri session. Work through them once after `nh os switch`.

**If something goes badly wrong:** from a TTY (Ctrl+Alt+F3), run `sudo nixos-rebuild switch --rollback`. To unlock a stuck lock screen: `loginctl unlock-sessions`.

## Logging in
- [ ] At SDDM, Left/Right (or a click on the session name under the password field) picks **Umbriel**, and logging in starts it.
- [ ] The hydrangea wallpaper shows rain only inside the framed picture, and the mist slowly brightens and dims.
- [ ] The live wallpapers follow the weather (`cat ~/.cache/rice/weather.json`): no rain on a clear day, only the mist. With `RICE_WEATHER=storm qs -c umbriel` the hydrangea's rain is heavy and slanted and the ruins get rain and frequent lightning; `RICE_WEATHER=drizzle` is light.
- [ ] Chain links sit top-left, the island top-centre, and faint status bottom-right.
- [ ] `pgrep -f '[q]s -c umbriel'` finds the shell; `pgrep -f '[q]s -c rice'` finds nothing; `systemctl --user is-active awww` says `inactive`.

## Keys and terminal
- [ ] Mod+T opens kitty, floating and centred at 1100×680 like niri's foot, in slate with the monochrome prompt. `umbriel focused-window` says `umbriel-term`.
- [ ] Spot-check Mod+D, Super+E, the volume and brightness keys, Print, and Mod+1..9.
- [ ] Mod+Alt+V shows clipboard history from this session after you copy something.
- [ ] `pkexec true` prompts for a password.
- [ ] `cava -p ~/.config/umbriel-term/cava.conf` shows the slate-to-bright gradient.
- [ ] In kew, `kew theme umbriel` gives the slate theme.

## Workspaces, island, launcher
- [ ] Switching workspace makes the active link swing ("clink"). Clicking a link switches workspace.
- [ ] Playing music in kew opens the island to bars, "title · artist" and the time, then it shrinks back.
- [ ] `notify-send hi` shows for about 5 s. `notify-send -u critical x` stays until you click it.
- [ ] The volume and brightness keys show the OSD in the island. Brightness may lag up to 0.5 s.
- [ ] Mod+Space drops the launcher out of the island and the viper slides out. Typing `fir` then Enter makes the viper strike, and Firefox launches.
- [ ] Gibberish gives an empty list, and Enter does nothing.
- [ ] A `Terminal=true` app such as btop opens in the slate kitty, floating at the same size, and Mod+Q closes it without a confirm prompt.
- [ ] Clicking outside the launcher closes it. Also try with a fullscreen window focused.
- [ ] The viper's horns aren't cut off at the top edge.

## Hidden details
- [ ] Within an hour the spider has dropped from the island at least once. To see it every 10 s, run `qs kill -c umbriel; UMBRIEL_HIDDEN_DEBUG=1 qs -c umbriel`.
- [ ] With debug on, cycle all 8 wallpapers (Mod+Ctrl+W). The eyes appear in a dark spot on each, and never over a window.

## Viper and raven
- [ ] The viper hangs head down under the island with venom on its fang, and its horns aren't clipped. At 1x on your wallpapers (pale and dark), the outline and the venom bead read clearly.
- [ ] Its tongue flicks every 10-20 s. Is that too often or too rare?
- [ ] Drops land on the top edge of a floating window's title bar, and fade over window content or the bare desktop. Also try a window on a second output, if any.
- [ ] The drip speeds up under load: `nix shell nixpkgs#stress-ng -c stress-ng --cpu 0 -t 15s` gives a drop about every 0.6 s, and it calms again afterwards.
- [ ] With a real fullscreen window (not nested), the viper hisses and retreats, and returns when you leave. It also retreats while the island is expanded.
- [ ] The raven sits at the left end of the status row. Its size beside the status row looks right, and it has contrast on your wallpapers. Sheen strength is fine.
- [ ] It breathes, blinks and looks about. Caws, hops and the trinket's fall are smooth at 144 Hz.
- [ ] A notice (`notify-send hi`) makes it caw. Its trinket falls from the island, it catches it, and the trinket lands in the hoard. The mask doesn't block clicks near that corner.
- [ ] Rest the pointer near the raven: after 2 s it watches, then hops and pecks, and settles after about 5 s. Does the timing feel right?
- [ ] The preen (head turned under the wing, nibbling for about 2 s) looks right. To see it every 20 s: `qs kill -c umbriel; UMBRIEL_RAVEN_DEBUG=1 qs -c umbriel`.
- [ ] At night (21:00-06:00) it sleeps with its head tucked in. A notice wakes it, it caws and catches, then sleeps again after about 20 s. With the debug env var it is night for 30 s of every 2 minutes.
- [ ] Locking (Super+Alt+L) and screen-off stop both: the shell's CPU drops. Fullscreen hides the raven, and it redraws afterwards.
- [ ] CPU in the real session: with windows maximised and idle for 60 s, the whole shell stays under about 4% (nested measurement was 3.3-4%). Also watch the compositor while a trinket falls and while the taller island window is up.

## Look
- [ ] The film grain is visible only if you look for it. It's still grain; moving grain cost about 2.3% CPU.
- [ ] Windows bleed in from their centre like ink in water (Mod+T): tendrils with a soft dark fringe, the content dark and grey at first and clear by the end. Mod+Q darkens the window and drains it back to a point. No tint is left on the settled window. Every window does this, not only kitty.
- [ ] Window borders are slate, not blue. The Bluetooth glyph is grey, with no colour fringe.

## Fullscreen and games
- [ ] A fullscreen video hides the corners and the island, and leaving fullscreen brings them back. A critical notice still shows over fullscreen.
- [ ] Mod+Shift+F on any window removes the grain, and leaving fullscreen brings it back.
- [ ] Super+S starts Steam through Xwayland. With a game fullscreen, `umbriel effects` shows eDP-2 `SUPPRESSED yes`.

## Lock, idle, power
- [ ] Super+Alt+L locks and unlocks. Within about 2 s of locking, the shell's CPU drops to about 0.2%.
- [ ] Killing the locker (`pkill -f '[q]s -c rice-lock'`) leaves the session locked. Unlock it from a TTY with `loginctl unlock-sessions`.
- [ ] After 10 minutes idle the screen turns off, and it wakes on input.
- [ ] Mod+Shift+Q, then Log out, ends the session.

## CPU
- [ ] With all windows maximised and idle for 60 s, the shell stays under 2%: `top -d 60 -p $(pgrep -f 'quickshell -c umbriel' | head -1)`.
- [ ] With the desktop idle, check the compositor: `top -d 60 -p $(pgrep -x .umbriel-wrappe)` (read the second sample). To see the grain's own share, run `umbriel msg effect-screen-set off`, then `umbriel msg effect-screen-reset`.

## Back to niri
- [ ] Log out and pick niri. You get the unchanged rice: matugen colours, the bar with the koi, and locking working.
- [ ] `systemctl --user list-timers | grep rice-wall` shows the rotation about 45 minutes out.
- [ ] New foot terminals use the matugen prompt, not the Umbriel one. Also try logging back into niri within 10 s of leaving Umbriel.
