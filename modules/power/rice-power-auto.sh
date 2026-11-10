set -euo pipefail
# rice-power-auto: unplugged, the laptop goes to power-saver; plugged back in,
# it returns to the profile it had on AC. Run by rice-power-auto.service
# (udev starts it when a charger comes or goes, and at boot and on resume).
#
# It only acts when the supply changed since its last run, so a profile you
# pick by hand stays put. Plugging back in restores the AC profile only if the
# laptop is still on the profile this script chose; a choice you made on
# battery is kept. While a game runs (gamemode's rice-game-power) or anything
# holds a profile (`powerprofilesctl launch`) it changes nothing.

state_dir=${RICE_POWER_STATE_DIR:-/var/lib/rice-power}
supply_dir=${RICE_POWER_SUPPLY_DIR:-/sys/class/power_supply}
battery_profile=${RICE_POWER_BATTERY_PROFILE:-power-saver}
# A glob, expanded below.
game_notes=${RICE_POWER_GAME_NOTES:-/run/user/*/rice-game/profile}

# "ac" when any mains or USB charger is online. A machine with no mains
# supply at all (a desktop) is always on AC.
supply() {
  local d type seen=0
  for d in "$supply_dir"/*; do
    type=$(cat "$d/type" 2>/dev/null || true)
    case $type in Mains | USB) ;; *) continue ;; esac
    [ "$type" = Mains ] && seen=1
    if [ "$(cat "$d/online" 2>/dev/null || true)" = 1 ]; then
      echo ac
      return
    fi
  done
  if [ "$seen" = 1 ]; then echo battery; else echo ac; fi
}

valid() { case $1 in power-saver | balanced | performance) return 0 ;; *) return 1 ;; esac; }

mkdir -p "$state_dir"
now=$(supply)
last=$(cat "$state_dir/supply" 2>/dev/null || true)
echo "$now" > "$state_dir/supply"
[ -n "$last" ] && [ "$last" != "$now" ] || exit 0

if ! current=$(powerprofilesctl get 2>/dev/null); then
  echo "rice-power-auto: power-profiles-daemon not answering; left alone"
  exit 0
fi
if [ -n "$(powerprofilesctl list-holds 2>/dev/null || true)" ]; then
  echo "rice-power-auto: $now, but a profile is held; left alone"
  rm -f "$state_dir/set-by-us"
  exit 0
fi

# A game is running (rice-game-power, modules/gaming, has a note of the
# profile it replaced): the game keeps its profile, and the noted one is what
# you had on AC.
game_note=""
for f in $game_notes; do
  [ -s "$f" ] && game_note=$(cat "$f") && break
done
if [ -n "$game_note" ]; then
  [ "$now" = battery ] && valid "$game_note" && echo "$game_note" > "$state_dir/ac-profile"
  rm -f "$state_dir/set-by-us"
  echo "rice-power-auto: $now, but a game is running; left alone"
  exit 0
fi

if [ "$now" = battery ]; then
  valid "$current" && echo "$current" > "$state_dir/ac-profile"
  if [ "$current" != "$battery_profile" ]; then
    powerprofilesctl set "$battery_profile"
    echo "$battery_profile" > "$state_dir/set-by-us"
    echo "rice-power-auto: on battery, $current -> $battery_profile"
  else
    rm -f "$state_dir/set-by-us"
  fi
else
  target=$(cat "$state_dir/ac-profile" 2>/dev/null || true)
  valid "$target" || target=balanced
  ours=$(cat "$state_dir/set-by-us" 2>/dev/null || true)
  rm -f "$state_dir/set-by-us"
  if [ -n "$ours" ] && [ "$current" = "$ours" ] && [ "$current" != "$target" ]; then
    powerprofilesctl set "$target"
    echo "rice-power-auto: on AC, $current -> $target"
  fi
fi
