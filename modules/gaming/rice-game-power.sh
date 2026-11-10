# rice-game-power start|end: gamemode's custom start and end scripts
# (configuration.nix, programs.gamemode.settings.custom). On start it notes
# the power profile in use and asks for "performance"; on end it puts the
# noted one back. Only through powerprofilesctl, which the power automation
# uses too, so neither writes behind the other's back:
#  - a second start (gamemode restarted mid-game) keeps the first note;
#  - if the profile is no longer "performance" at the end, someone chose
#    another one while playing, and that choice stands;
#  - no daemon or no powerprofilesctl: nothing happens, quietly.
# The note lives in $RICE_GAME_POWER_DIR (default $XDG_RUNTIME_DIR/rice-game),
# so a reboot forgets it.

dir=${RICE_GAME_POWER_DIR:-${XDG_RUNTIME_DIR:-/tmp}/rice-game}
note=$dir/profile

case ${1:-} in
  start | end) ;;
  *)
    echo "usage: rice-game-power start|end" >&2
    exit 2
    ;;
esac

command -v powerprofilesctl >/dev/null 2>&1 || exit 0
now=$(powerprofilesctl get 2>/dev/null) || exit 0

if [ "$1" = start ]; then
  mkdir -p "$dir"
  [ -s "$note" ] || printf '%s\n' "$now" > "$note"
  [ "$now" = performance ] || powerprofilesctl set performance 2>/dev/null || true
else
  [ -s "$note" ] || exit 0
  was=$(cat "$note")
  rm -f "$note"
  if [ "$now" = performance ] && [ "$was" != performance ]; then
    powerprofilesctl set "$was" 2>/dev/null || true
  fi
fi
exit 0
