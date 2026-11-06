#!/usr/bin/env bash
# Tests for modules/theme/rice-wall.sh (run: bash tests/rice-wall-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
RICE_WALL=$PWD/modules/theme/rice-wall.sh

walls() { for w in "$@"; do : > "$RICE_WALL_DIR/$w"; done; }

test_next_wraps() {
  stub awww; stub matugen
  walls a.jpg b.jpg c.jpg
  echo "$RICE_WALL_DIR/c.jpg" > "$RICE_STATE_DIR/current"
  bash "$RICE_WALL" next
  assert_eq "$(cat "$RICE_STATE_DIR/current")" "$RICE_WALL_DIR/a.jpg"
}

test_next_calls_awww_then_matugen() {
  stub awww; stub matugen
  walls a.jpg b.jpg
  echo "$RICE_WALL_DIR/a.jpg" > "$RICE_STATE_DIR/current"
  bash "$RICE_WALL" next
  local calls; calls=$(cat "$TMP/calls")
  assert_eq "$(sed -n 1p "$TMP/calls" | cut -d' ' -f1-3)" "awww img $RICE_WALL_DIR/b.jpg"
  assert_contains "$calls" "--transition-type fade"
  assert_contains "$(sed -n 2p "$TMP/calls")" "matugen image $RICE_WALL_DIR/b.jpg -t scheme-content --prefer saturation -m dark"
}

test_set_missing_path_fails() {
  stub awww; stub matugen
  local err code=0
  err=$(bash "$RICE_WALL" set "$TMP/nope.jpg" 2>&1 >/dev/null) || code=$?
  assert_eq "$code" "1"
  assert_contains "$err" "no such wallpaper"
}

test_matugen_failure_keeps_colours() {
  stub awww; stub matugen 1
  walls a.jpg b.jpg
  echo "$RICE_WALL_DIR/a.jpg" > "$RICE_STATE_DIR/current"
  echo '{"primary":"KEEP"}' > "$RICE_STATE_DIR/colors.json"
  local err code=0
  err=$(bash "$RICE_WALL" next 2>&1 >/dev/null) || code=$?
  assert_eq "$code" "0"
  assert_contains "$(cat "$RICE_STATE_DIR/colors.json")" "KEEP"
  assert_eq "$(cat "$RICE_STATE_DIR/current")" "$RICE_WALL_DIR/b.jpg"
  assert_contains "$err" "keeping previous colours"
}

test_init_without_awww() {
  stub awww; stub matugen
  walls b.jpg a.jpg
  bash "$RICE_WALL" init
  assert_eq "$(cat "$RICE_STATE_DIR/current")" "$RICE_WALL_DIR/a.jpg"
  ! grep -q '^awww' "$TMP/calls"
  grep -q '^matugen image' "$TMP/calls"
}

test_current_prints_path() {
  stub awww; stub matugen
  echo "$RICE_WALL_DIR/x.jpg" > "$RICE_STATE_DIR/current"
  assert_eq "$(bash "$RICE_WALL" current)" "$RICE_WALL_DIR/x.jpg"
}

for t in test_next_wraps test_next_calls_awww_then_matugen test_set_missing_path_fails \
  test_matugen_failure_keeps_colours test_init_without_awww test_current_prints_path; do
  run_test "$t"
done
finish
