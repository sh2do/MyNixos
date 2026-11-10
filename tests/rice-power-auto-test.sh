#!/usr/bin/env bash
# Tests for modules/power/rice-power-auto.sh (run: bash tests/rice-power-auto-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
AUTO=$PWD/modules/power/rice-power-auto.sh

# A fake power-profiles-daemon: the profile lives in $TMP/profile, holds in $TMP/holds.
stub_ppd() {
  echo "${1:-balanced}" > "$TMP/profile"
  : > "$TMP/holds"
  cat > "$TMP/bin/powerprofilesctl" <<EOF
#!/usr/bin/env bash
echo "powerprofilesctl \$*" >> "$TMP/calls"
case \$1 in
  get) cat "$TMP/profile" ;;
  set) echo "\$2" > "$TMP/profile" ;;
  list-holds) cat "$TMP/holds" ;;
esac
EOF
  chmod +x "$TMP/bin/powerprofilesctl"
}

# supply NAME TYPE ONLINE
supply() {
  mkdir -p "$TMP/supply/$1"
  echo "$2" > "$TMP/supply/$1/type"
  echo "$3" > "$TMP/supply/$1/online"
}
plug() { supply ADP1 Mains 1; }
unplug() { supply ADP1 Mains 0; }

auto() {
  RICE_POWER_STATE_DIR="$TMP/power" RICE_POWER_SUPPLY_DIR="$TMP/supply" \
    RICE_POWER_GAME_NOTES="$TMP/run/user/*/rice-game/profile" bash "$AUTO"
}
profile() { cat "$TMP/profile"; }
sets() { grep -c '^powerprofilesctl set' "$TMP/calls" || true; }

test_first_run_only_records() {
  stub_ppd performance; unplug
  auto
  assert_eq "$(profile)" "performance"
  assert_eq "$(sets)" "0"
  assert_eq "$(cat "$TMP/power/supply")" "battery"
}

test_unplug_goes_to_saver_and_remembers_ac_profile() {
  stub_ppd performance; plug; auto
  unplug; auto
  assert_eq "$(profile)" "power-saver"
  assert_eq "$(cat "$TMP/power/ac-profile")" "performance"
}

test_plug_back_restores_ac_profile() {
  stub_ppd performance; plug; auto
  unplug; auto
  plug; auto
  assert_eq "$(profile)" "performance"
}

test_same_state_twice_does_nothing() {
  stub_ppd balanced; plug; auto
  unplug; auto
  echo balanced > "$TMP/profile" # chosen by hand on battery
  auto
  assert_eq "$(profile)" "balanced"
  assert_eq "$(sets)" "1"
}

test_manual_choice_on_battery_is_kept_on_plug() {
  stub_ppd balanced; plug; auto
  unplug; auto
  echo performance > "$TMP/profile"
  plug; auto
  assert_eq "$(profile)" "performance"
  assert_eq "$(sets)" "1"
}

test_already_saver_on_ac_sets_nothing() {
  stub_ppd power-saver; plug; auto
  unplug; auto
  plug; auto
  assert_eq "$(profile)" "power-saver"
  assert_eq "$(sets)" "0"
}

test_holds_are_left_alone() {
  stub_ppd performance; plug; auto
  echo "Hold: gamemode performance" > "$TMP/holds"
  unplug; auto
  assert_eq "$(profile)" "performance"
  assert_eq "$(sets)" "0"
  plug; auto
  assert_eq "$(sets)" "0"
}

# A game is on (rice-game-power noted "balanced" and set performance): the
# game keeps performance, and the AC profile to come back to is the noted one.
test_game_keeps_performance_and_its_note_is_the_ac_profile() {
  stub_ppd balanced; plug; auto
  mkdir -p "$TMP/run/user/1000/rice-game"
  echo balanced > "$TMP/run/user/1000/rice-game/profile"
  echo performance > "$TMP/profile"
  unplug; auto
  assert_eq "$(profile)" "performance"
  assert_eq "$(sets)" "0"
  assert_eq "$(cat "$TMP/power/ac-profile")" "balanced"
  plug; auto
  assert_eq "$(sets)" "0"
}

test_usb_c_charger_counts_as_ac() {
  stub_ppd balanced; plug; auto
  unplug; supply ucsi USB 1; auto
  assert_eq "$(profile)" "balanced"
  assert_eq "$(cat "$TMP/power/supply")" "ac"
}

test_no_mains_supply_means_ac() {
  stub_ppd balanced
  mkdir -p "$TMP/supply"; auto
  assert_eq "$(cat "$TMP/power/supply")" "ac"
}

test_junk_remembered_profile_falls_back_to_balanced() {
  stub_ppd balanced; plug; auto
  unplug; auto
  echo "nonsense" > "$TMP/power/ac-profile"
  plug; auto
  assert_eq "$(profile)" "balanced"
}

test_daemon_missing_is_not_an_error() {
  plug; auto
  unplug
  stub powerprofilesctl 1
  local code=0
  auto || code=$?
  assert_eq "$code" "0"
}

for t in $(declare -F | awk '$3 ~ /^test_/ { print $3 }'); do run_test "$t"; done
finish
