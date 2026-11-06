#!/usr/bin/env bash
# Tests for modules/rofi/rice-menu.sh (run: bash tests/rice-menu-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
RICE_MENU=$PWD/modules/rofi/rice-menu.sh

# rofi stub: logs its args, prints $RICE_TEST_CHOICE, exits $RICE_TEST_ROFI_EXIT
stub_rofi() {
  cat > "$TMP/bin/rofi" <<EOF
#!/usr/bin/env bash
cat > /dev/null
echo "rofi \$*" >> "$TMP/calls"
[ "\${RICE_TEST_ROFI_EXIT:-0}" = 0 ] || exit "\$RICE_TEST_ROFI_EXIT"
printf '%s\n' "\$RICE_TEST_CHOICE"
EOF
  chmod +x "$TMP/bin/rofi"
}

stubs() { stub_rofi; stub systemctl; stub powerprofilesctl; stub rice-wall; stub rice-lock; stub niri; }

test_power_shutdown() {
  stubs
  RICE_TEST_CHOICE="Shut down" bash "$RICE_MENU" power
  grep -qx 'systemctl poweroff' "$TMP/calls"
}

test_power_lock() {
  stubs
  RICE_TEST_CHOICE="Lock" bash "$RICE_MENU" power
  grep -qx 'rice-lock' "$TMP/calls"
}

test_profile_sets() {
  stubs
  RICE_TEST_CHOICE="  performance" bash "$RICE_MENU" profile
  grep -qx 'powerprofilesctl set performance' "$TMP/calls"
}

test_wallpaper_sets() {
  stubs
  mkdir -p "$RICE_WALL_DIR"; : > "$RICE_WALL_DIR/a.jpg"
  RICE_TEST_CHOICE="$RICE_WALL_DIR/a.jpg" bash "$RICE_MENU" wallpaper
  grep -qx "rice-wall set $RICE_WALL_DIR/a.jpg" "$TMP/calls"
}

test_cancel_does_nothing() {
  stubs
  local code=0
  RICE_TEST_ROFI_EXIT=1 bash "$RICE_MENU" power || code=$?
  assert_eq "$code" "0"
  ! grep -qv '^rofi' "$TMP/calls"
}

test_unknown_mode() {
  stubs
  local code=0
  bash "$RICE_MENU" bogus 2>/dev/null || code=$?
  assert_eq "$code" "2"
}

for t in test_power_shutdown test_power_lock test_profile_sets test_wallpaper_sets \
  test_cancel_does_nothing test_unknown_mode; do
  run_test "$t"
done
finish
