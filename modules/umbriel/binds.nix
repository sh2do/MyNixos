# Umbriel keybinds, ported from modules/niri/binds.kdl so muscle memory
# carries over. Defining keybinds replaces Umbriel's built-in set, so this is
# the whole working set. Actions: docs/user/actions.md in the umbriel input.
#
# Left out, with no Umbriel equivalent: Mod+Alt+W (rice-wall next is niri's
# awww), Mod+Ctrl+R (reset window height), Mod+Ctrl+F (expand column to the
# free width), Mod+Ctrl+C (centre all visible columns), Alt+Print (window shot).
{ lib, term }:  # term: ~/.config/umbriel-term, expanded

let
  once = action: { inherit action; repeat = false; };
  locked = action: { inherit action; allow_when_locked = true; };
  wheel = action: { inherit action; cooldown_ms = 150; };

  # Screenshots go where niri puts them, and onto the clipboard.
  # spawn runs its command through the shell.
  shot = grim: ''f=~/Pictures/Screenshots/$(date +%F_%H-%M-%S).png; mkdir -p ~/Pictures/Screenshots && ${grim} "$f" && wl-copy < "$f"'';

  # Mod+1..9 switch workspace, Mod+Ctrl+1..9 move the column there.
  workspaces = lib.listToAttrs (lib.concatMap (n: let i = toString n; in [
    (lib.nameValuePair "Mod+${i}" "workspace-switch ${i}")
    (lib.nameValuePair "Mod+Ctrl+${i}" "column-move-to-workspace ${i}")
  ]) (lib.range 1 9));
in
workspaces // {
  "Mod+Shift+Slash" = once "cheatsheet-toggle";

  # Rice: launcher, menus and wallpapers (the shell is "qs -c umbriel")
  "Mod+Space" = once "spawn qs -c umbriel ipc call launcher toggle";
  "Mod+Alt+V" = once "spawn rice-menu clipboard";
  "Mod+Shift+Q" = once "spawn rice-menu power";
  "Mod+Ctrl+W" = once "spawn qs -c umbriel ipc call picker toggle";
  "Mod+Alt+F" = once "spawn rice-focus toggle";

  # Programs
  "Mod+T" = once "spawn env STARSHIP_CONFIG=${term}/starship.toml kitty --class umbriel-term --config ${term}/kitty.conf";
  "Mod+D" = once "spawn firefox";
  "Super+Alt+L" = once "spawn rice-lock";
  "Super+S" = once "spawn steam";
  "Super+E" = once "spawn nautilus";
  "Super+Z" = once "spawn discord";
  "Super+X" = once "spawn kate";
  "Super+A" = once "spawn antigravity";
  "Super+Alt+S" = locked "spawn pkill orca || exec orca";

  # Volume, media and brightness, also while locked
  "XF86AudioRaiseVolume" = locked "spawn wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0";
  "XF86AudioLowerVolume" = locked "spawn wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-";
  "XF86AudioMute" = locked "spawn wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
  "XF86AudioMicMute" = locked "spawn wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
  "XF86AudioPlay" = locked "spawn playerctl play-pause";
  "XF86AudioStop" = locked "spawn playerctl stop";
  "XF86AudioPrev" = locked "spawn playerctl previous";
  "XF86AudioNext" = locked "spawn playerctl next";
  "XF86MonBrightnessUp" = locked "spawn brightnessctl --class=backlight set +10%";
  "XF86MonBrightnessDown" = locked "spawn brightnessctl --class=backlight set 10%-";

  "Mod+O" = once "overview-toggle";
  "Mod+Q" = once "window-close";

  # Focus and move, within the workspace
  "Mod+Left" = "window-focus-left";
  "Mod+Down" = "window-focus-down";
  "Mod+Up" = "window-focus-up";
  "Mod+Right" = "window-focus-right";
  "Mod+H" = "window-focus-left";
  "Mod+J" = "window-focus-down";
  "Mod+K" = "window-focus-up";
  "Mod+L" = "window-focus-right";

  "Mod+Ctrl+Left" = "column-move-left";
  "Mod+Ctrl+Down" = "window-move-down";
  "Mod+Ctrl+Up" = "window-move-up";
  "Mod+Ctrl+Right" = "column-move-right";
  "Mod+Ctrl+H" = "column-move-left";
  "Mod+Ctrl+J" = "window-move-down";
  "Mod+Ctrl+K" = "window-move-up";
  "Mod+Ctrl+L" = "column-move-right";

  "Mod+Home" = "column-focus-first";
  "Mod+End" = "column-focus-last";
  "Mod+Ctrl+Home" = "column-move-to-first";
  "Mod+Ctrl+End" = "column-move-to-last";

  # Monitors
  "Mod+Shift+Left" = "output-focus-left";
  "Mod+Shift+Down" = "output-focus-down";
  "Mod+Shift+Up" = "output-focus-up";
  "Mod+Shift+Right" = "output-focus-right";
  "Mod+Shift+H" = "output-focus-left";
  "Mod+Shift+J" = "output-focus-down";
  "Mod+Shift+K" = "output-focus-up";
  "Mod+Shift+L" = "output-focus-right";

  "Mod+Shift+Ctrl+Left" = "column-move-to-output-left";
  "Mod+Shift+Ctrl+Down" = "column-move-to-output-down";
  "Mod+Shift+Ctrl+Up" = "column-move-to-output-up";
  "Mod+Shift+Ctrl+Right" = "column-move-to-output-right";
  "Mod+Shift+Ctrl+H" = "column-move-to-output-left";
  "Mod+Shift+Ctrl+J" = "column-move-to-output-down";
  "Mod+Shift+Ctrl+K" = "column-move-to-output-up";
  "Mod+Shift+Ctrl+L" = "column-move-to-output-right";

  # Workspaces (down = next)
  "Mod+Page_Down" = "workspace-next";
  "Mod+Page_Up" = "workspace-previous";
  "Mod+U" = "workspace-next";
  "Mod+I" = "workspace-previous";
  "Mod+Ctrl+Page_Down" = "column-move-to-workspace-next";
  "Mod+Ctrl+Page_Up" = "column-move-to-workspace-previous";
  "Mod+Ctrl+U" = "column-move-to-workspace-next";
  "Mod+Ctrl+I" = "column-move-to-workspace-previous";

  "Mod+Shift+Page_Down" = "workspace-move-down";
  "Mod+Shift+Page_Up" = "workspace-move-up";
  "Mod+Shift+U" = "workspace-move-down";
  "Mod+Shift+I" = "workspace-move-up";

  # Wheel
  "Mod+WheelDown" = wheel "workspace-next";
  "Mod+WheelUp" = wheel "workspace-previous";
  "Mod+Ctrl+WheelDown" = wheel "column-move-to-workspace-next";
  "Mod+Ctrl+WheelUp" = wheel "column-move-to-workspace-previous";

  "Mod+WheelRight" = "window-focus-right";
  "Mod+WheelLeft" = "window-focus-left";
  "Mod+Ctrl+WheelRight" = "column-move-right";
  "Mod+Ctrl+WheelLeft" = "column-move-left";

  "Mod+Shift+WheelDown" = "window-focus-right";
  "Mod+Shift+WheelUp" = "window-focus-left";
  "Mod+Ctrl+Shift+WheelDown" = "column-move-right";
  "Mod+Ctrl+Shift+WheelUp" = "column-move-left";

  # Columns and sizes
  "Mod+BracketLeft" = "window-consume-or-expel-left";
  "Mod+BracketRight" = "window-consume-or-expel-right";
  "Mod+Comma" = "window-consume-from-right";
  "Mod+Period" = "window-consume-or-expel-right";

  "Mod+R" = "window-cycle-primary-extent";
  "Mod+Shift+R" = "window-cycle-primary-extent-back";
  "Mod+Ctrl+Shift+R" = "window-cycle-secondary-extent";

  "Mod+F" = once "window-toggle-maximize";
  "Mod+Shift+F" = once "window-toggle-fullscreen";
  "Mod+M" = once "window-toggle-maximize-to-edges";
  "Mod+C" = "column-center";

  "Mod+Minus" = "window-modify-primary-extent -0.1";
  "Mod+Equal" = "window-modify-primary-extent +0.1";
  "Mod+Shift+Minus" = "window-modify-secondary-extent -0.1";
  "Mod+Shift+Equal" = "window-modify-secondary-extent +0.1";

  "Mod+V" = once "window-toggle-floating";
  "Mod+Shift+V" = once "window-focus-switch-floating";
  "Mod+W" = once "column-toggle-tabbed";

  # Screenshots: a region, or the whole screen
  "Print" = once "spawn ${shot ''grim -g "$(slurp)"''}";
  "Ctrl+Print" = once "spawn ${shot "grim"}";

  # Escape hatch for apps that inhibit shortcuts
  "Mod+Escape" = { action = "shortcuts-inhibit-toggle"; allow_when_inhibited = true; repeat = false; };

  # Quit (asks first) and monitors off (any input wakes them)
  "Mod+Shift+E" = once "session-quit";
  "Ctrl+Alt+Delete" = once "session-quit";
  "Mod+Shift+P" = once "dpms-off";
}
