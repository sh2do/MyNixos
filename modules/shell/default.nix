# The Quickshell config "rice" (bar, top pill, wallpaper picker).
# Deployed as ~/.config/quickshell/rice; niri starts it with `qs -c rice`.
{ lib, pkgs, ... }:

let
  # Shows a message on the paired phone (KDE Connect); the bar also forwards
  # critical notifications through it. kdeconnect-cli comes from the system's
  # programs.kdeconnect, so it matches the running daemon.
  phone-alert = pkgs.writeShellApplication {
    name = "phone-alert";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./phone-alert.sh;
  };

  # Fills KDE Connect's "Run command" list (lock, music, volume, wallpaper,
  # screenshot, sleep) for each paired phone; kdeconnect-cli as above.
  phone-commands = pkgs.writeShellApplication {
    name = "phone-commands";
    runtimeInputs = with pkgs; [ coreutils gnused jq procps ];
    text = builtins.readFile ./phone-commands.sh;
  };
in
{
  # The top pill's visualiser reads cava's raw output while music plays.
  # zenity: the phone chip's "send a file" picker.
  home.packages = [ pkgs.cava pkgs.zenity phone-alert phone-commands ];

  # The raven (RICE_MASCOT=raven) is Umbriel's: its art, life and moods are
  # copied in from there, so both shells draw it from one source.
  xdg.configFile."quickshell/rice".source = pkgs.runCommand "rice-shell" { } ''
    cp -r ${lib.cleanSourceWith {
      src = ./.;
      filter = path: type: type == "directory" || lib.any (ext: lib.hasSuffix ext path) [ ".qml" ".svg" ".js" ];
    }} $out
    chmod -R u+w $out
    cp ${../umbriel/shell/RavenBody.qml} $out/RavenBody.qml
    cp ${../umbriel/shell/RavenLife.qml} $out/RavenLife.qml
    cp ${../umbriel/shell/raven-mood.js} $out/raven-mood.js
  '';

  # Keep the phone's buttons in step with the list in phone-commands.sh.
  home.activation.phoneCommands = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    PATH=/run/current-system/sw/bin:$PATH run ${phone-commands}/bin/phone-commands || true
  '';

  # A running bar keeps watching the old store path, so a switch never reaches it.
  # Restart it through niri (for the session's environment) when its files changed.
  home.activation.restartRiceBar = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    old=$(readlink -f "''${oldGenPath:-/nonexistent}/home-files/.config/quickshell/rice" || true)
    new=$(readlink -f "$newGenPath/home-files/.config/quickshell/rice")
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    sock=$(ls "$XDG_RUNTIME_DIR"/niri.*.sock 2>/dev/null | head -n 1 || true)
    if [ "$old" != "$new" ] && [ -n "$sock" ]; then
      run ${pkgs.quickshell}/bin/qs kill -c rice >/dev/null 2>&1 || true
      run env NIRI_SOCKET="$sock" ${pkgs.niri}/bin/niri msg action spawn -- qs -c rice
    fi
  '';
}
