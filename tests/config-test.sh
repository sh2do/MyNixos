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

test_leftovers_are_gone() {
  assert_eq "$(sys_eval environment.systemPackages --apply 'ps: builtins.any (p: builtins.elem (p.pname or "") [ "zsh" "fetch" ]) ps')" 'false'
  assert_eq "$(git -C "$FLAKE" ls-files Configs)" ''
  [ ! -e "$FLAKE/dotfiles/ghostty/themes/dankcolors" ]
}

# Umbriel publishes `environment` to the systemd user manager, which outlives the
# session: anything set there leaks into a niri login that follows.
test_umbriel_starship_only_on_its_own_terminals() {
  local env bind
  env=$(hm_eval programs.umbriel.settings --apply 's: (s.environment or {}).STARSHIP_CONFIG or null')
  assert_eq "$env" 'null'
  bind=$(hm_eval programs.umbriel.settings.keybinds --apply 'b: builtins.toJSON b."Mod+T"')
  assert_contains "$bind" "STARSHIP_CONFIG="
  assert_contains "$bind" "kitty --class umbriel-term --config"
  local launcher
  launcher=$(cat "$FLAKE/modules/umbriel/shell/Launcher.qml")
  assert_contains "$launcher" "STARSHIP_CONFIG="
  assert_contains "$launcher" '"kitty", "--class", "umbriel-term"'
}

# Umbriel's kitty floats at the size niri gives foot (modules/niri/rules.kdl).
test_umbriel_terminal_floats_like_foot() {
  assert_eq "$(hm_eval programs.umbriel.settings.window_rule --apply 'rs: builtins.filter (r: r.match.app_id == "^umbriel-term$") rs')" \
    '[{"default_floating":true,"default_floating_size_px":{"height":680,"width":1100},"match":{"app_id":"^umbriel-term$"}}]'
  assert_contains "$(hm_eval 'xdg.configFile."umbriel-term/kitty.conf".source' | jq -r . | xargs cat)" "background           #0a0b0e"
}

test_umbriel_keeps_clipboard_history() {
  assert_contains "$(hm_eval programs.umbriel.settings.general.autostart)" "wl-paste --watch cliphist store"
}

# Like the niri bar, the running Umbriel shell watches its old store path.
test_umbriel_shell_restarts_on_switch() {
  assert_contains "$(hm_eval home.activation.restartUmbrielShell.data)" "qs kill -c umbriel"
}

# The rofi glass: matugen renders the drips, rofi uses them, niri blurs behind rofi.
test_menus_are_dripping_glass() {
  local mg templates theme rules
  mg=$(hm_eval 'xdg.configFile."matugen/config.toml".source' | jq -r .)
  templates=$(hm_eval 'xdg.configFile."matugen/templates".source' | jq -r .)
  theme=$(hm_eval 'xdg.configFile."rofi/theme.rasi".source' | jq -r .)
  rules=$(hm_eval 'xdg.configFile."niri/rules.kdl".source' | jq -r .)
  local name
  for name in drips drip-row; do
    assert_contains "$(cat "$mg")" "[templates.$name]"
    assert_contains "$(cat "$mg")" 'rsvg-convert \"$HOME/.cache/rice/'"$name"'.svg\" -o \"$HOME/.cache/rice/'"$name"'.png\"'
    assert_contains "$(cat "$templates/$name.svg")" "{{colors.primary.default.hex}}"
    assert_contains "$(cat "$theme")" "~/.cache/rice/$name.png"
  done
  assert_contains "$(tr -s ' \n' ' ' < "$rules")" 'match namespace="^rofi$" geometry-corner-radius 16 background-effect { blur true }'
}

for t in test_polkit_agent_runs_in_every_graphical_session test_look_is_declared test_leftovers_are_gone \
  test_umbriel_starship_only_on_its_own_terminals test_umbriel_terminal_floats_like_foot test_umbriel_keeps_clipboard_history test_umbriel_shell_restarts_on_switch \
  test_menus_are_dripping_glass; do
  run_test "$t"
done
finish
