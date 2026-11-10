#!/usr/bin/env bash
# Tests for modules/gaming/rice-game-power.sh (run: bash tests/rice-game-power-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
SCRIPT=$PWD/modules/gaming/rice-game-power.sh

# A fake powerprofilesctl: `get` prints $TMP/profile, `set X` writes it.
fake_ppd() {
  echo "${1:-balanced}" > "$TMP/profile"
  cat > "$TMP/bin/powerprofilesctl" <<EOF2
#!/usr/bin/env bash
echo "powerprofilesctl \$*" >> "$TMP/calls"
case \$1 in
  get) cat "$TMP/profile" ;;
  set) echo "\$2" > "$TMP/profile" ;;
esac
EOF2
  chmod +x "$TMP/bin/powerprofilesctl"
}
power() { RICE_GAME_POWER_DIR="$TMP/run" bash "$SCRIPT" "$@"; }
profile() { cat "$TMP/profile"; }

test_start_saves_and_goes_performance() {
  fake_ppd power-saver
  power start
  assert_eq "$(profile)" "performance"
  assert_eq "$(cat "$TMP/run/profile")" "power-saver"
}

test_end_restores_the_saved_profile() {
  fake_ppd balanced
  power start
  power end
  assert_eq "$(profile)" "balanced"
  [ ! -e "$TMP/run/profile" ]
}

test_start_again_keeps_the_first_saved_profile() {
  fake_ppd balanced
  power start
  power start
  assert_eq "$(cat "$TMP/run/profile")" "balanced"
  power end
  assert_eq "$(profile)" "balanced"
}

test_already_performance_is_left_alone_at_end() {
  fake_ppd performance
  power start
  power end
  assert_eq "$(profile)" "performance"
  ! grep -q "set" "$TMP/calls"
}

# Something else (the user, the power automation) moved off performance
# mid-game: that choice stands.
test_end_respects_a_change_made_while_playing() {
  fake_ppd balanced
  power start
  echo power-saver > "$TMP/profile"
  power end
  assert_eq "$(profile)" "power-saver"
  [ ! -e "$TMP/run/profile" ]
}

test_end_without_start_does_nothing() {
  fake_ppd balanced
  power end
  assert_eq "$(profile)" "balanced"
  ! grep -q "set" "$TMP/calls"
}

test_no_powerprofilesctl_is_quiet_success() {
  # coreutils only (the system bin dir has powerprofilesctl in it).
  local core sh
  core=$(dirname "$(readlink -f "$(command -v mkdir)")")
  sh=$(command -v bash)
  PATH="$TMP/bin:$core" RICE_GAME_POWER_DIR="$TMP/run" "$sh" "$SCRIPT" start
  PATH="$TMP/bin:$core" RICE_GAME_POWER_DIR="$TMP/run" "$sh" "$SCRIPT" end
  [ ! -e "$TMP/run/profile" ]
}

test_daemon_down_is_quiet_success() {
  stub powerprofilesctl 1
  power start
  power end
  [ ! -e "$TMP/run/profile" ]
}

test_bad_argument_is_usage() {
  fake_ppd
  set +e
  power sideways 2>/dev/null
  rc=$?
  set -e
  assert_eq "$rc" "2"
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do run_test "$t"; done
finish
