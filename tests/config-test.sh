#!/usr/bin/env bash
# Checks on the evaluated NixOS / Home Manager config (run: bash tests/config-test.sh).
# Slow-ish: every check is a `nix eval` of the flake.
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
FLAKE=$PWD

# hm_eval ATTR [nix eval args...] — Home Manager option for Zaion, as JSON
hm_eval() { local a=$1; shift; nix eval --json "$FLAKE#nixosConfigurations.nixos.config.home-manager.users.Zaion.$a" "$@"; }
# sys_eval ATTR [nix eval args...] — NixOS option, as JSON
sys_eval() { local a=$1; shift; nix eval --json "$FLAKE#nixosConfigurations.nixos.config.$a" "$@"; }

test_polkit_agent_runs_in_every_graphical_session() {
  assert_eq "$(hm_eval systemd.user.services.polkit-agent.Install.WantedBy)" '["graphical-session.target"]'
  assert_contains "$(hm_eval systemd.user.services.polkit-agent.Service.ExecStart)" "polkit-gnome-authentication-agent-1"
}

test_look_is_declared() {
  assert_eq "$(hm_eval home.pointerCursor.name)" '"Bibata-Modern-Classic"'
  assert_eq "$(hm_eval home.pointerCursor.size)" '24'
  assert_eq "$(hm_eval gtk.iconTheme.name)" '"Papirus-Dark"'
  assert_eq "$(hm_eval gtk.theme.name)" '"adw-gtk3-dark"'
  assert_eq "$(hm_eval gtk.font.name)" '"Rubik"'
  assert_eq "$(sys_eval services.displayManager.sddm.settings.Theme.CursorTheme)" '"Bibata-Modern-Classic"'
  assert_eq "$(sys_eval environment.systemPackages --apply 'ps: builtins.any (p: (p.pname or "") == "nwg-look") ps')" 'false'
  # matugen owns gtk.css (modules/theme), so Home Manager must not write it
  local files
  files=$(hm_eval xdg.configFile --apply builtins.attrNames)
  if grep -qE '"gtk-[34]\.0/gtk\.css"' <<<"$files"; then
    echo "    Home Manager writes gtk.css"
    return 1
  fi
}

for t in test_polkit_agent_runs_in_every_graphical_session test_look_is_declared; do
  run_test "$t"
done
finish
