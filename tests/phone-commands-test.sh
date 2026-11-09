#!/usr/bin/env bash
# Tests for modules/shell/phone-commands.sh (run: bash tests/phone-commands-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
PHONE_COMMANDS=$PWD/modules/shell/phone-commands.sh

# A paired phone "abc_1" in a fake KDE Connect config dir.
pair() {
  export KDECONNECT_CONFIG="$TMP/kc"
  mkdir -p "$KDECONNECT_CONFIG"
  printf '[abc_1]\nname=Test phone\ntype=phone\n' > "$KDECONNECT_CONFIG/trusted_devices"
}

# The commands JSON, unescaped from the KConfig @ByteArray(...) value.
commands_json() {
  sed -n 's/^commands="@ByteArray(\(.*\))"$/\1/p' "$KDECONNECT_CONFIG/abc_1/kdeconnect_runcommand/config" \
    | sed 's/\\"/"/g; s/\\\\/\\/g'
}

test_writes_buttons_for_paired_phone() {
  pair; stub pkill 1; stub kdeconnect-cli
  bash "$PHONE_COMMANDS" >/dev/null
  json=$(commands_json)
  assert_eq "$(jq -r '.rice_lock.command' <<<"$json")" "rice-lock"
  assert_eq "$(jq -r '.rice_play.name' <<<"$json")" "Play / pause"
  assert_eq "$(jq -r '.rice_focus.name' <<<"$json")" "Focus"
  assert_eq "$(jq -r '.rice_focus.command' <<<"$json")" "rice-focus toggle"
  # The screenshot button sends to this phone.
  assert_contains "$(jq -r '.rice_shot.command' <<<"$json")" "kdeconnect-cli -d abc_1 --share"
}

test_restarts_running_daemon_on_change() {
  pair; stub pkill 0; stub kdeconnect-cli
  bash "$PHONE_COMMANDS" >/dev/null
  assert_contains "$(cat "$TMP/calls")" "pkill -x kdeconnectd"
  assert_contains "$(cat "$TMP/calls")" "kdeconnect-cli -l"
}

test_unchanged_does_nothing() {
  pair; stub pkill 0; stub kdeconnect-cli
  bash "$PHONE_COMMANDS" >/dev/null
  : > "$TMP/calls"
  out=$(bash "$PHONE_COMMANDS")
  assert_eq "$(cat "$TMP/calls")" ""
  assert_contains "$out" "already set"
}

test_no_phone_is_quiet_success() {
  export KDECONNECT_CONFIG="$TMP/none"
  stub pkill 0; stub kdeconnect-cli
  out=$(bash "$PHONE_COMMANDS")
  assert_contains "$out" "no paired phone"
  assert_eq "$(cat "$TMP/calls")" ""
}

run_test test_writes_buttons_for_paired_phone
run_test test_restarts_running_daemon_on_change
run_test test_unchanged_does_nothing
run_test test_no_phone_is_quiet_success
finish
