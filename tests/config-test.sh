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

for t in test_polkit_agent_runs_in_every_graphical_session; do
  run_test "$t"
done
finish
