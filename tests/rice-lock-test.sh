#!/usr/bin/env bash
# Tests for modules/lock/rice-lock.sh (run: bash tests/rice-lock-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
LOCK=$PWD/modules/lock/rice-lock.sh

# fake qs that marks the lock secure after a short delay, like the real one
stub_qs_locks() {
  cat > "$TMP/bin/qs" <<EOF
#!/usr/bin/env bash
echo "qs \$*" >> "$TMP/calls"
sleep 0.3; touch "\$XDG_RUNTIME_DIR/rice-lock.secure"; sleep 5
EOF
  chmod +x "$TMP/bin/qs"
}

run_lock() {
  XDG_RUNTIME_DIR=$TMP RICE_LOCK_WAIT=${RICE_LOCK_WAIT:-3} bash -euo pipefail "$LOCK"
}

test_returns_once_locked() {
  stub_qs_locks
  local start=$SECONDS
  run_lock
  [ -e "$TMP/rice-lock.secure" ]
  assert_eq "$(( SECONDS - start < 3 ))" "1"
}

test_starts_lock_config_without_duplicates() {
  stub_qs_locks
  run_lock
  assert_contains "$(cat "$TMP/calls")" "qs -c rice-lock -n"
}

test_fails_when_lock_never_engages() {
  stub qs
  local rc=0
  RICE_LOCK_WAIT=1 run_lock || rc=$?
  assert_eq "$rc" "1"
}

test_already_locked_returns_at_once() {
  stub qs
  touch "$TMP/rice-lock.secure"
  RICE_LOCK_WAIT=1 run_lock
}

for t in test_returns_once_locked test_starts_lock_config_without_duplicates \
         test_fails_when_lock_never_engages test_already_locked_returns_at_once; do
  run_test "$t"
done
finish
