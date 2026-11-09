#!/usr/bin/env bash
# Tests for modules/shell/rice-focus.sh (run: bash tests/rice-focus-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
RICE_FOCUS=$PWD/modules/shell/rice-focus.sh

focus() { RICE_FOCUS_NOW=1000 bash "$RICE_FOCUS" "$@"; }
state() { cat "$RICE_STATE_DIR/focus"; }

test_on_writes_the_start() {
  out=$(focus on)
  assert_eq "$(state)" "on 1000"
  assert_eq "$out" "focus on"
}

test_off_writes_off() {
  focus on >/dev/null
  out=$(focus off)
  assert_eq "$(state)" "off"
  assert_eq "$out" "focus off"
}

test_toggle_flips_and_is_the_default() {
  focus toggle >/dev/null
  assert_eq "$(state)" "on 1000"
  focus >/dev/null
  assert_eq "$(state)" "off"
}

test_on_again_keeps_the_first_start() {
  echo "on 500" > "$RICE_STATE_DIR/focus"
  focus on >/dev/null
  assert_eq "$(state)" "on 500"
}

test_status_reads_without_writing() {
  assert_eq "$(focus status)" "focus off"
  [ ! -e "$RICE_STATE_DIR/focus" ]
  echo "on 500" > "$RICE_STATE_DIR/focus"
  assert_eq "$(focus status)" "focus on"
}

test_makes_the_state_dir() {
  export RICE_STATE_DIR="$TMP/new/dir"
  focus on >/dev/null
  assert_eq "$(state)" "on 1000"
}

test_bad_argument_fails_with_usage() {
  set +e
  out=$(focus sideways 2>&1)
  rc=$?
  set -e
  assert_eq "$rc" "2"
  assert_contains "$out" "usage: rice-focus"
}

run_test test_on_writes_the_start
run_test test_off_writes_off
run_test test_toggle_flips_and_is_the_default
run_test test_on_again_keeps_the_first_start
run_test test_status_reads_without_writing
run_test test_makes_the_state_dir
run_test test_bad_argument_fails_with_usage
finish
