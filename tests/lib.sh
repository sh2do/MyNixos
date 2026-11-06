# Tiny test helpers shared by the shell-script tests.
# Each test runs in its own temp dir with stub commands first on PATH.

TESTS_RUN=0
TESTS_FAILED=0

setup_sandbox() {
  TMP=$(mktemp -d)
  export RICE_STATE_DIR="$TMP/state"
  export RICE_WALL_DIR="$TMP/walls"
  mkdir -p "$RICE_STATE_DIR" "$RICE_WALL_DIR" "$TMP/bin"
  : > "$TMP/calls"
  export PATH="$TMP/bin:$ORIG_PATH"
}

# stub NAME [EXIT_CODE] — fake command that logs "NAME args..." to $TMP/calls
stub() {
  local name=$1 code=${2:-0}
  cat > "$TMP/bin/$name" <<EOF
#!/usr/bin/env bash
echo "$name\${*:+ \$*}" >> "$TMP/calls"
exit $code
EOF
  chmod +x "$TMP/bin/$name"
}

assert_eq() {
  if [ "$1" != "$2" ]; then
    echo "    expected: $2"
    echo "    actual:   $1"
    return 1
  fi
}

assert_contains() {
  if ! grep -qF -- "$2" <<<"$1"; then
    echo "    expected to contain: $2"
    echo "    in: $1"
    return 1
  fi
}

run_test() {
  TESTS_RUN=$((TESTS_RUN + 1))
  setup_sandbox
  # Not inside `if` or `||`: either would switch off set -e in the test.
  ( set -e; "$1" )
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "PASS $1"
  else
    echo "FAIL $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  rm -rf "$TMP"
}

finish() {
  echo "$((TESTS_RUN - TESTS_FAILED))/$TESTS_RUN passed"
  [ "$TESTS_FAILED" -eq 0 ]
}

ORIG_PATH=$PATH
