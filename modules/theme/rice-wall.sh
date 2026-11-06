set -euo pipefail
# rice-wall: owns the current wallpaper and recolours the desktop from it.
#
#   rice-wall init        pick a wallpaper if none is set and generate colours (no awww)
#   rice-wall next        show the next wallpaper in the rotation
#   rice-wall set PATH    show PATH (RICE_TRANSITION=grow grows it in from the centre)
#   rice-wall pick        choose one with rofi (rice-menu wallpaper)
#   rice-wall current     print the current wallpaper path
#
# Colours come from matugen, which writes every themed file listed in its
# config. If matugen fails the wallpaper still changes and the old colours stay.

state_dir=${RICE_STATE_DIR:-$HOME/.cache/rice}
wall_dir=${RICE_WALL_DIR:-$HOME/.local/share/wallpapers/rotation}
matugen_config=${RICE_MATUGEN_CONFIG:-$HOME/.config/matugen/config.toml}
current_file=$state_dir/current

die() {
  echo "rice-wall: $*" >&2
  exit 1
}

rotation() {
  find -L "$wall_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort
}

current() {
  [ -s "$current_file" ] && cat "$current_file"
}

recolour() {
  if ! matugen image "$1" -t scheme-content --prefer saturation -m dark -c "$matugen_config" >/dev/null; then
    echo "rice-wall: matugen failed, keeping previous colours" >&2
  fi
}

show() {
  local wall=$1
  [ -f "$wall" ] || die "no such wallpaper: $wall"
  mkdir -p "$state_dir"
  echo "$wall" > "$current_file"
  local transition=(--transition-type fade --transition-duration 1.2)
  if [ "${RICE_TRANSITION:-}" = grow ]; then
    transition=(--transition-type grow --transition-pos center --transition-duration 1.4)
  fi
  awww img "$wall" "${transition[@]}" --resize crop ||
    echo "rice-wall: awww failed (is awww-daemon running?)" >&2
  recolour "$wall"
}

next() {
  local now first="" found=0 wall
  now=$(current || true)
  while IFS= read -r wall; do
    [ -z "$first" ] && first=$wall
    if [ "$found" = 1 ]; then
      show "$wall"
      return
    fi
    [ "$wall" = "$now" ] && found=1
  done < <(rotation)
  [ -n "$first" ] || die "no wallpapers in $wall_dir"
  show "$first"
}

init() {
  local wall
  wall=$(current || true)
  if [ -z "$wall" ] || [ ! -f "$wall" ]; then
    wall=$(rotation | head -n 1)
    [ -n "$wall" ] || die "no wallpapers in $wall_dir"
    mkdir -p "$state_dir"
    echo "$wall" > "$current_file"
  fi
  recolour "$wall"
}

case ${1:-} in
  init) init ;;
  next) next ;;
  set) show "${2:?usage: rice-wall set PATH}" ;;
  pick) exec rice-menu wallpaper ;;
  current) current || die "no wallpaper set" ;;
  *)
    echo "usage: rice-wall {init|next|set PATH|pick|current}" >&2
    exit 2
    ;;
esac
