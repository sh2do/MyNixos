#!/usr/bin/env bash
# Tests for modules/lock/rice-dpms.sh (run: bash tests/rice-dpms-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
RICE_DPMS=$PWD/modules/lock/rice-dpms.sh

test_dpms_uses_umbriel_when_umbriel_socket_set() {
  stub umbriel; stub niri
  UMBRIEL_SOCKET=/x bash "$RICE_DPMS" off
  assert_eq "$(cat "$TMP/calls")" "umbriel msg dpms-off"
}

test_dpms_uses_niri_otherwise() {
  stub umbriel; stub niri
  env -u UMBRIEL_SOCKET bash "$RICE_DPMS" off
  assert_eq "$(cat "$TMP/calls")" "niri msg action power-off-monitors"
}

test_dpms_on_is_a_no_op_on_niri() {
  stub umbriel; stub niri
  env -u UMBRIEL_SOCKET bash "$RICE_DPMS" on
  assert_eq "$(cat "$TMP/calls")" ""
}

test_dpms_rejects_unknown_arg() {
  stub umbriel; stub niri
  local code=0
  bash "$RICE_DPMS" sideways 2>/dev/null || code=$?
  [ "$code" -ne 0 ]
  assert_eq "$(cat "$TMP/calls")" ""
}

for t in test_dpms_uses_umbriel_when_umbriel_socket_set test_dpms_uses_niri_otherwise test_dpms_on_is_a_no_op_on_niri \
  test_dpms_rejects_unknown_arg; do
  run_test "$t"
done
finish
