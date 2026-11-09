#!/usr/bin/env bash
# Tests for modules/shell/rice-clip.sh (run: bash tests/rice-clip-test.sh)
# Uses the real cliphist on a throwaway database (CLIPHIST_DB_PATH), never the user's.
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
RICE_CLIP=$PWD/modules/shell/rice-clip.sh

# A 2x1 PNG.
PNG=iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAAEUlEQVR4nGP4z8DwnwEIGBgAHvAC/sOsBBUAAAAASUVORK5CYII=

db() {
  export CLIPHIST_DB_PATH=$TMP/db
  export RICE_CLIP_DELAY=0
  printf 'first text' | cliphist store
  base64 -d <<<"$PNG" | cliphist store
  printf 'second text' | cliphist store
}

# wl-copy stub that keeps what it was given.
stub_wl_copy() {
  cat > "$TMP/bin/wl-copy" <<EOF
#!/usr/bin/env bash
cat > "$TMP/copied"
echo "wl-copy \$*" >> "$TMP/calls"
EOF
  chmod +x "$TMP/bin/wl-copy"
}

# niri stub answering focused-window with app id $RICE_TEST_APP.
stub_niri() {
  cat > "$TMP/bin/niri" <<EOF
#!/usr/bin/env bash
printf '{"app_id":"%s"}\n' "\$RICE_TEST_APP"
EOF
  chmod +x "$TMP/bin/niri"
}

line_of() { bash "$RICE_CLIP" list | grep -m1 -F "$1"; }

test_list_is_cliphist_list() {
  db
  out=$(bash "$RICE_CLIP" list)
  assert_contains "$out" "second text"
  assert_contains "$out" "[[ binary data"
  assert_eq "$(wc -l <<<"$out")" 3
}

test_copy_decodes_the_entry() {
  db; stub_wl_copy
  bash "$RICE_CLIP" copy "$(line_of 'first text')"
  assert_eq "$(cat "$TMP/copied")" "first text"
}

test_delete_removes_only_that_entry() {
  db
  bash "$RICE_CLIP" delete "$(line_of 'first text')"
  out=$(bash "$RICE_CLIP" list)
  ! grep -q 'first text' <<<"$out"
  assert_contains "$out" "second text"
  assert_eq "$(wc -l <<<"$out")" 2
}

test_thumbs_decodes_images_and_drops_stale_ones() {
  db
  id=$(line_of 'binary data' | cut -f1)
  mkdir -p "$TMP/thumbs"; : > "$TMP/thumbs/999.png"
  bash "$RICE_CLIP" thumbs "$TMP/thumbs"
  assert_eq "$(ls "$TMP/thumbs")" "$id.png"
  cmp <(base64 -d <<<"$PNG") "$TMP/thumbs/$id.png"
}

test_paste_uses_ctrl_v_in_apps() {
  db; stub_wl_copy; stub_niri; stub wtype
  RICE_TEST_APP=firefox bash "$RICE_CLIP" paste "$(line_of 'second text')"
  assert_eq "$(cat "$TMP/copied")" "second text"
  grep -qx 'wtype -M ctrl -k v -m ctrl' "$TMP/calls"
}

test_paste_uses_ctrl_shift_v_in_terminals() {
  db; stub_wl_copy; stub_niri; stub wtype
  RICE_TEST_APP=foot bash "$RICE_CLIP" paste "$(line_of 'second text')"
  grep -qx 'wtype -M ctrl -M shift -k v -m shift -m ctrl' "$TMP/calls"
}

test_paste_without_wtype_just_copies() {
  db; stub_wl_copy; stub_niri
  RICE_TEST_APP=firefox RICE_CLIP_WTYPE=/nonexistent/wtype bash "$RICE_CLIP" paste "$(line_of 'second text')"
  assert_eq "$(cat "$TMP/copied")" "second text"
}

test_emoji_copies_and_types() {
  export RICE_CLIP_DELAY=0
  stub_wl_copy; stub wtype
  bash "$RICE_CLIP" emoji "🐟"
  assert_eq "$(cat "$TMP/copied")" "🐟"
  grep -qx 'wtype 🐟' "$TMP/calls"
}

test_unknown_command_fails() {
  ! bash "$RICE_CLIP" frobnicate 2>/dev/null
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do run_test "$t"; done
finish
