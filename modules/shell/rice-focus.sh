# rice-focus [on|off|toggle|status]: focus mode for both shells. It writes
# $RICE_STATE_DIR/focus ("on <epoch seconds>" or "off"), which the niri bar
# and Umbriel's shell watch (Focus.qml): while on, notifications are held
# (critical ones still show) and summed up on one card when it ends, the
# raven sleeps, the koi drift and Umbriel's viper hangs still.
# The default is toggle. RICE_FOCUS_NOW fixes the clock (tests).

state_dir=${RICE_STATE_DIR:-$HOME/.cache/rice}
file=$state_dir/focus

current=$(cat "$file" 2>/dev/null || true)
on=0
case $current in
  "on "*) on=1 ;;
esac

case ${1:-toggle} in
  on) want=1 ;;
  off) want=0 ;;
  toggle) want=$((1 - on)) ;;
  status)
    [ "$on" = 1 ] && echo "focus on" || echo "focus off"
    exit 0
    ;;
  *)
    echo "usage: rice-focus [on|off|toggle|status]" >&2
    exit 2
    ;;
esac

mkdir -p "$state_dir"
if [ "$want" = 1 ]; then
  # Already on: keep when it started.
  [ "$on" = 1 ] || printf 'on %s\n' "${RICE_FOCUS_NOW:-$(date +%s)}" > "$file"
  echo "focus on"
else
  printf 'off\n' > "$file"
  echo "focus off"
fi
