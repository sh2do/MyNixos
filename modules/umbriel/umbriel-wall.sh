set -euo pipefail
# umbriel-wall: remembers which wallpaper the Umbriel shell shows.
# There is no rotation; the shell's picker calls `set`, and the shell's
# Background watches the state file and reloads when it changes.
#
#   umbriel-wall current    print the current id (xe9223 if none or unknown)
#   umbriel-wall set ID     remember ID, which must be a file in the wall dir
#   umbriel-wall list       print every id in the wall dir, sorted
#
# An id is a file name without its extension (Wallhaven IDs).

state_dir=${UMBRIEL_STATE_DIR:-$HOME/.local/state/umbriel}
wall_dir=${UMBRIEL_WALL_DIR:-$HOME/.local/share/wallpapers/umbriel}
current_file=$state_dir/current
default_id=xe9223

die() {
  echo "umbriel-wall: $*" >&2
  exit 1
}

list() {
  [ -d "$wall_dir" ] || return 0
  find -L "$wall_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    -printf '%f\n' | sed 's/\.[^.]*$//' | LC_ALL=C sort -u
}

known() {
  list | grep -qxF -- "$1"
}

case ${1:-} in
  current)
    id=
    [ -s "$current_file" ] && id=$(head -n1 "$current_file")
    if [ -n "$id" ] && known "$id"; then echo "$id"; else echo "$default_id"; fi
    ;;
  set)
    [ $# -eq 2 ] || die "usage: umbriel-wall set ID"
    known "$2" || die "no such wallpaper: $2"
    mkdir -p "$state_dir"
    # Write then rename, so the shell's file watcher never sees half a file.
    echo "$2" > "$current_file.tmp"
    mv -f "$current_file.tmp" "$current_file"
    ;;
  list)
    list
    ;;
  *)
    die "usage: umbriel-wall current | set ID | list"
    ;;
esac
