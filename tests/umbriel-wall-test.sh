#!/usr/bin/env bash
# Tests for modules/umbriel/umbriel-wall.sh (run: bash tests/umbriel-wall-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
UMBRIEL_WALL=$PWD/modules/umbriel/umbriel-wall.sh

# The sandbox gives RICE_* dirs; point umbriel-wall at its own pair inside it.
umbriel_dirs() {
  export UMBRIEL_STATE_DIR="$TMP/ustate" UMBRIEL_WALL_DIR="$TMP/uwalls"
  mkdir -p "$UMBRIEL_WALL_DIR"
}

walls() { for w in "$@"; do : > "$UMBRIEL_WALL_DIR/$w"; done; }

test_current_defaults_to_hydrangea() {
  umbriel_dirs
  walls xe9223.jpg mly2vm.png
  assert_eq "$(bash "$UMBRIEL_WALL" current)" "xe9223"
}

test_set_then_current() {
  umbriel_dirs
  walls xe9223.jpg mly2vm.png
  bash "$UMBRIEL_WALL" set mly2vm
  assert_eq "$(bash "$UMBRIEL_WALL" current)" "mly2vm"
}

test_set_rejects_unknown() {
  umbriel_dirs
  walls xe9223.jpg mly2vm.png
  bash "$UMBRIEL_WALL" set mly2vm
  local err code=0
  err=$(bash "$UMBRIEL_WALL" set nope 2>&1 >/dev/null) || code=$?
  [ "$code" -ne 0 ]
  assert_contains "$err" "no such wallpaper"
  assert_eq "$(cat "$UMBRIEL_STATE_DIR/current")" "mly2vm"
}

test_current_falls_back_on_unknown_id() {
  umbriel_dirs
  walls xe9223.jpg mly2vm.png
  mkdir -p "$UMBRIEL_STATE_DIR"
  echo gone > "$UMBRIEL_STATE_DIR/current"
  assert_eq "$(bash "$UMBRIEL_WALL" current)" "xe9223"
}

test_list_prints_all_ids() {
  umbriel_dirs
  walls xe9223.jpg jeyo1m.jpg mly2vm.png neko5k.jpg 2e2xyx.jpg 427owm.jpg rdrqz7.jpg vqv3p8.jpg
  assert_eq "$(bash "$UMBRIEL_WALL" list)" "$(printf '%s\n' 2e2xyx 427owm jeyo1m mly2vm neko5k rdrqz7 vqv3p8 xe9223)"
}

test_unknown_command_fails() {
  umbriel_dirs
  local code=0
  bash "$UMBRIEL_WALL" frobnicate >/dev/null 2>&1 || code=$?
  [ "$code" -ne 0 ]
}

for t in test_current_defaults_to_hydrangea test_set_then_current test_set_rejects_unknown \
  test_current_falls_back_on_unknown_id test_list_prints_all_ids test_unknown_command_fails; do
  run_test "$t"
done
finish
