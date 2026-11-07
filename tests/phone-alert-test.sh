#!/usr/bin/env bash
# Tests for modules/shell/phone-alert.sh (run: bash tests/phone-alert-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
PHONE_ALERT=$PWD/modules/shell/phone-alert.sh

# kdeconnect-cli stub: logs its args; `-a --id-only` prints $RICE_TEST_IDS
# (one per line, none when empty); a ping exits $RICE_TEST_PING_EXIT.
stub_cli() {
  cat > "$TMP/bin/kdeconnect-cli" <<EOF
#!/usr/bin/env bash
printf 'kdeconnect-cli' >> "$TMP/calls"
printf ' [%s]' "\$@" >> "$TMP/calls"
echo >> "$TMP/calls"
case "\$*" in
  *--id-only*)
    [ -n "\${RICE_TEST_IDS:-}" ] && printf '%s\n' \$RICE_TEST_IDS
    [ -z "\${RICE_TEST_IDS:-}" ] && echo "0 devices found" >&2
    exit "\${RICE_TEST_LIST_EXIT:-0}" ;;
  *--ping-msg*) exit "\${RICE_TEST_PING_EXIT:-0}" ;;
esac
EOF
  chmod +x "$TMP/bin/kdeconnect-cli"
}

test_pings_first_reachable_device() {
  stub_cli
  RICE_TEST_IDS="aaa_1 bbb_2" bash "$PHONE_ALERT" "switch done"
  grep -qxF 'kdeconnect-cli [-d] [aaa_1] [--ping-msg] [switch done]' "$TMP/calls"
  ! grep -q bbb_2 "$TMP/calls"
}

test_joins_words() {
  stub_cli
  RICE_TEST_IDS="aaa_1" bash "$PHONE_ALERT" switch done
  grep -qxF 'kdeconnect-cli [-d] [aaa_1] [--ping-msg] [switch done]' "$TMP/calls"
}

test_critical_prefixes() {
  stub_cli
  RICE_TEST_IDS="aaa_1" bash "$PHONE_ALERT" --critical "Battery low"
  grep -qxF 'kdeconnect-cli [-d] [aaa_1] [--ping-msg] [Critical: Battery low]' "$TMP/calls"
}

test_double_dash_ends_options() {
  stub_cli
  RICE_TEST_IDS="aaa_1" bash "$PHONE_ALERT" -- --critical
  grep -qxF 'kdeconnect-cli [-d] [aaa_1] [--ping-msg] [--critical]' "$TMP/calls"
}

test_none_reachable_fails_clearly() {
  stub_cli
  local err rc=0
  err=$(RICE_TEST_IDS="" bash "$PHONE_ALERT" "hello" 2>&1 >/dev/null) || rc=$?
  assert_eq "$rc" 1
  assert_contains "$err" "no paired phone is reachable"
  ! grep -q -- --ping-msg "$TMP/calls"
}

test_daemon_down_fails_clearly() {
  stub_cli
  local err rc=0
  err=$(RICE_TEST_IDS="" RICE_TEST_LIST_EXIT=1 bash "$PHONE_ALERT" "hello" 2>&1 >/dev/null) || rc=$?
  assert_eq "$rc" 1
  assert_contains "$err" "no paired phone is reachable"
}

test_cli_missing_fails_clearly() {
  # No stub on PATH at all (and no real one either).
  local err rc=0
  err=$(PATH="$TMP/bin:/nonexistent" "$BASH" "$PHONE_ALERT" "hello" 2>&1 >/dev/null) || rc=$?
  assert_eq "$rc" 1
  assert_contains "$err" "kdeconnect-cli"
}

test_ping_failure_propagates() {
  stub_cli
  local err rc=0
  err=$(RICE_TEST_IDS="aaa_1" RICE_TEST_PING_EXIT=1 bash "$PHONE_ALERT" "hello" 2>&1 >/dev/null) || rc=$?
  assert_eq "$rc" 1
  assert_contains "$err" "could not reach"
}

test_no_message_is_usage_error() {
  stub_cli
  local err rc=0
  err=$(RICE_TEST_IDS="aaa_1" bash "$PHONE_ALERT" 2>&1 >/dev/null) || rc=$?
  assert_eq "$rc" 2
  assert_contains "$err" "usage: phone-alert"
  rc=0
  RICE_TEST_IDS="aaa_1" bash "$PHONE_ALERT" --critical 2>/dev/null || rc=$?
  assert_eq "$rc" 2
  rc=0
  RICE_TEST_IDS="aaa_1" bash "$PHONE_ALERT" "" 2>/dev/null || rc=$?
  assert_eq "$rc" 2
  ! grep -q -- --ping-msg "$TMP/calls"
}

test_unknown_option_is_usage_error() {
  stub_cli
  local rc=0
  RICE_TEST_IDS="aaa_1" bash "$PHONE_ALERT" --loud "hi" 2>/dev/null || rc=$?
  assert_eq "$rc" 2
  ! grep -q -- --ping-msg "$TMP/calls"
}

test_help() {
  local out
  out=$(bash "$PHONE_ALERT" --help)
  assert_contains "$out" "usage: phone-alert"
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  run_test "$t"
done
finish
