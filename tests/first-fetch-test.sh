#!/usr/bin/env bash
# Tests for modules/terminal/rice-first-fetch.fish (run: bash tests/first-fetch-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
FN=$PWD/modules/terminal/rice-first-fetch.fish

open_shell() {
  XDG_RUNTIME_DIR=$TMP fish --no-config -c "source $FN; rice_first_fetch"
}

test_first_shell_runs_fetch() {
  stub fastfetch
  open_shell
  assert_eq "$(grep -c '^fastfetch' "$TMP/calls")" "1"
}

test_second_shell_skips() {
  stub fastfetch
  open_shell
  open_shell
  assert_eq "$(grep -c '^fastfetch' "$TMP/calls")" "1"
}

for t in test_first_shell_runs_fetch test_second_shell_skips; do
  run_test "$t"
done
finish
