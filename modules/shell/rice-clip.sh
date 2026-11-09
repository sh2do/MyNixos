set -euo pipefail
# rice-clip: the clipboard and emoji panel's hands (modules/shell/ClipPicker.qml).
#
#   rice-clip list          the history, as `cliphist list` prints it
#   rice-clip thumbs DIR    decode the newest image entries into DIR/<id>.<ext>
#                           (only missing ones) and drop the rest
#   rice-clip copy LINE     put a history entry back on the clipboard
#   rice-clip paste LINE    copy it, then paste into the focused window
#   rice-clip delete LINE   remove it from the history
#   rice-clip emoji CHAR    copy an emoji and type it into the focused window
#
# Pasting and typing need wtype ($RICE_CLIP_WTYPE); without it they only copy.
# They wait $RICE_CLIP_DELAY seconds first, for the panel to close and give the
# keyboard back.

delay=${RICE_CLIP_DELAY:-0.35}
wtype_cmd=${RICE_CLIP_WTYPE:-wtype}
max_thumbs=48

have_wtype() { command -v "$wtype_cmd" >/dev/null 2>&1; }

copy() {
  cliphist decode <<<"$1" | wl-copy
}

# Terminals paste with Ctrl+Shift+V; everything else with Ctrl+V.
paste_keys() {
  local app
  app=$(niri msg -j focused-window 2>/dev/null | jq -r '.app_id // ""' 2>/dev/null || true)
  case $app in
    foot | footclient | kitty | Alacritty | *ghostty | *wezterm | org.gnome.Console | org.gnome.Ptyxis | *konsole | xterm*)
      "$wtype_cmd" -M ctrl -M shift -k v -m shift -m ctrl ;;
    *) "$wtype_cmd" -M ctrl -k v -m ctrl ;;
  esac
}

thumbs() {
  local dir=$1 keep=() id ext f
  mkdir -p "$dir"
  while IFS=$'\t' read -r id ext; do
    f=$dir/$id.$ext
    keep+=("$id.$ext")
    if [ ! -s "$f" ]; then
      cliphist decode "$id" > "$f.part" && mv "$f.part" "$f"
    fi
  done < <(cliphist list | sed -nE 's/^([0-9]+)\t\[\[ binary data .* (png|jpeg|jpg|gif|webp|bmp) [0-9]+x[0-9]+ \]\]$/\1\t\2/p' |
    sed 's/\tjpeg$/\tjpg/' | head -n "$max_thumbs")
  for f in "$dir"/*; do
    [ -e "$f" ] || continue
    [[ " ${keep[*]} " == *" ${f##*/} "* ]] || rm -f "$f"
  done
}

case ${1:-} in
  list) cliphist list ;;
  thumbs) thumbs "${2:?thumbs DIR}" ;;
  copy) copy "${2:?copy LINE}" ;;
  paste)
    copy "${2:?paste LINE}"
    if have_wtype; then
      sleep "$delay"
      paste_keys
    fi
    ;;
  delete) printf '%s\n' "${2:?delete LINE}" | cliphist delete ;;
  emoji)
    printf '%s' "${2:?emoji CHAR}" | wl-copy
    if have_wtype; then
      sleep "$delay"
      "$wtype_cmd" "$2"
    fi
    ;;
  *)
    echo "usage: rice-clip {list|thumbs DIR|copy LINE|paste LINE|delete LINE|emoji CHAR}" >&2
    exit 2
    ;;
esac
