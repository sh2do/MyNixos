#!/usr/bin/env bash
# Tests for modules/power/rice-fan.sh (run: bash tests/rice-fan-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
FAN=$PWD/modules/power/rice-fan.sh

# A fake /sys/class/hwmon: an unrelated chip and the hp-wmi one.
hwmon() {
  mkdir -p "$TMP/hwmon/hwmon0" "$TMP/hwmon/hwmon7"
  echo coretemp > "$TMP/hwmon/hwmon0/name"
  echo hp > "$TMP/hwmon/hwmon7/name"
  echo "${1:-2}" > "$TMP/hwmon/hwmon7/pwm1_enable"
  echo 2323 > "$TMP/hwmon/hwmon7/fan1_input"
  echo 2107 > "$TMP/hwmon/hwmon7/fan2_input"
}
fan() { RICE_HWMON_ROOT="$TMP/hwmon" bash "$FAN" "$@"; }
mode() { cat "$TMP/hwmon/hwmon7/pwm1_enable"; }

test_status_auto() {
  hwmon 2
  assert_eq "$(fan status)" "fan auto  cpu 2323 rpm  gpu 2107 rpm"
}

test_status_is_the_default() {
  hwmon 0
  assert_eq "$(fan)" "fan max  cpu 2323 rpm  gpu 2107 rpm"
}

test_status_manual() {
  hwmon 1
  assert_contains "$(fan status)" "fan manual"
}

test_max_writes_0() {
  hwmon 2
  assert_eq "$(fan max)" "fan max"
  assert_eq "$(mode)" "0"
}

test_auto_writes_2() {
  hwmon 0
  assert_eq "$(fan auto)" "fan auto"
  assert_eq "$(mode)" "2"
}

test_toggle_flips() {
  hwmon 2
  fan toggle >/dev/null
  assert_eq "$(mode)" "0"
  fan toggle >/dev/null
  assert_eq "$(mode)" "2"
}

test_toggle_from_manual_goes_auto() {
  hwmon 1
  fan toggle >/dev/null
  assert_eq "$(mode)" "2"
}

test_no_hp_hwmon_fails_cleanly() {
  mkdir -p "$TMP/hwmon/hwmon0"; echo coretemp > "$TMP/hwmon/hwmon0/name"
  local code=0 err
  err=$(fan status 2>&1) || code=$?
  assert_eq "$code" "1"
  assert_contains "$err" "no hp-wmi fan control"
}

test_read_only_says_why() {
  [ "$(id -u)" -ne 0 ] || return 0 # root can write anything
  hwmon 2
  chmod 0444 "$TMP/hwmon/hwmon7/pwm1_enable"
  local code=0 err
  err=$(fan max 2>&1) || code=$?
  assert_eq "$code" "1"
  assert_contains "$err" "can't write"
  assert_eq "$(mode)" "2"
}

test_bad_command_is_usage() {
  hwmon 2
  local code=0
  fan sideways 2>/dev/null || code=$?
  assert_eq "$code" "2"
}

for t in $(declare -F | awk '$3 ~ /^test_/ { print $3 }'); do run_test "$t"; done
finish
