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

stubs() { stub_rofi; stub systemctl; stub powerprofilesctl; stub rice-wall; stub rice-lock; stub niri; stub umbriel; }

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

test_logout_niri() {
  stubs
  env -u UMBRIEL_SOCKET RICE_TEST_CHOICE="Log out" bash "$RICE_MENU" power
  grep -qx 'niri msg action quit --skip-confirmation' "$TMP/calls"
}

test_logout_umbriel() {
  stubs
  UMBRIEL_SOCKET=/x RICE_TEST_CHOICE="Log out" bash "$RICE_MENU" power
  grep -qx 'umbriel msg session-quit skip-confirmation' "$TMP/calls"
  ! grep -q '^niri' "$TMP/calls"
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

# Until rice-wall has rendered the drip pill, the selected row falls back to a plain one.
test_selected_row_without_drips_is_plain() {
  stubs
  RICE_TEST_CHOICE="" bash "$RICE_MENU" power
  grep -qF 'element selected { background-color: @primary; }' "$TMP/calls"
}

test_selected_row_with_drips_uses_them() {
  stubs
  : > "$RICE_STATE_DIR/drip-row.png"
  RICE_TEST_CHOICE="" bash "$RICE_MENU" power
  ! grep -qF 'element selected { background-color: @primary; }' "$TMP/calls"
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

# rice-fan stub: `status` prints a status for $RICE_TEST_FAN (fails when empty,
# like a machine without fan control); other commands are just logged.
stub_fan() {
  cat > "$TMP/bin/rice-fan" <<EOF
#!/usr/bin/env bash
echo "rice-fan \$*" >> "$TMP/calls"
[ "\$1" = status ] || exit 0
[ -n "\${RICE_TEST_FAN:-}" ] || exit 1
echo "fan \$RICE_TEST_FAN  cpu 1 rpm  gpu 1 rpm"
EOF
  chmod +x "$TMP/bin/rice-fan"
}

# A rofi that keeps the rows it was offered in $TMP/rows and picks nothing.
stub_rofi_rows() {
  printf '#!/usr/bin/env bash\ncat > "%s/rows"\n' "$TMP" > "$TMP/bin/rofi"
  chmod +x "$TMP/bin/rofi"
}

test_profile_fan_boost_toggles() {
  stubs; stub_fan
  RICE_TEST_FAN=auto RICE_TEST_CHOICE="  󰈐 fan boost" bash "$RICE_MENU" profile
  grep -qx 'rice-fan toggle' "$TMP/calls"
  ! grep -q '^powerprofilesctl set' "$TMP/calls"
  : > "$TMP/calls"
  RICE_TEST_FAN=max RICE_TEST_CHOICE="● 󰈐 fan boost" bash "$RICE_MENU" profile
  grep -qx 'rice-fan toggle' "$TMP/calls"
}

test_profile_fan_boost_row_marks_max() {
  stubs; stub_fan; stub_rofi_rows
  RICE_TEST_FAN=max bash "$RICE_MENU" profile
  grep -qx '● 󰈐 fan boost' "$TMP/rows"
  RICE_TEST_FAN=auto bash "$RICE_MENU" profile
  grep -qx '  󰈐 fan boost' "$TMP/rows"
}

test_profile_without_fan_control_has_no_row() {
  stubs; stub_fan; stub_rofi_rows
  RICE_TEST_FAN="" bash "$RICE_MENU" profile
  grep -q 'balanced' "$TMP/rows"
  ! grep -q 'fan boost' "$TMP/rows"
}

for t in test_power_shutdown test_power_lock test_logout_niri test_logout_umbriel test_profile_sets test_wallpaper_sets \
  test_profile_fan_boost_toggles test_profile_fan_boost_row_marks_max test_profile_without_fan_control_has_no_row \
  test_selected_row_without_drips_is_plain test_selected_row_with_drips_uses_them \
  test_cancel_does_nothing test_unknown_mode; do
  run_test "$t"
done
finish
