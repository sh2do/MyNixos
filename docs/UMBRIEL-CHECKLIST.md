# Umbriel: first-login checklist

These checks need a real Umbriel login, which can't be tested from inside a niri session. Work through them once after `nh os switch`.

**If something goes badly wrong:** from a TTY (Ctrl+Alt+F3), run `sudo nixos-rebuild switch --rollback`. To unlock a stuck lock screen: `loginctl unlock-sessions`.

## Logging in
- [ ] At SDDM, Left/Right (or a click on the session name under the password field) picks **Umbriel**, and logging in starts it.
- [ ] The hydrangea wallpaper shows rain only inside the framed picture, and the mist slowly brightens and dims.
- [ ] Chain links sit top-left, the island top-centre, and faint status bottom-right.
- [ ] `pgrep -f '[q]s -c umbriel'` finds the shell; `pgrep -f '[q]s -c rice'` finds nothing; `systemctl --user is-active awww` says `inactive`.

## Keys and terminal
- [ ] Mod+T opens foot in slate with the monochrome prompt.
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
- [ ] A `Terminal=true` app such as btop opens in the slate foot.
- [ ] Clicking outside the launcher closes it. Also try with a fullscreen window focused.
- [ ] The viper's horns aren't cut off at the top edge.

## Hidden details
- [ ] Within an hour the spider has dropped from the island at least once. To see it every 10 s, run `qs kill -c umbriel; UMBRIEL_HIDDEN_DEBUG=1 qs -c umbriel`.
- [ ] With debug on, cycle all 8 wallpapers (Mod+Ctrl+W). The eyes appear in a dark spot on each, and never over a window.

## Look
- [ ] The film grain is visible only if you look for it. It's still grain; moving grain cost about 2.3% CPU.
- [ ] Windows open (Mod+T) through dark smoke and close (Mod+Q) through a grainy dissolve. Check for banding at the start of the smoke.
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
