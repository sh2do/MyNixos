# The Quickshell config "rice" (bar, top pill, wallpaper picker).
# Deployed as ~/.config/quickshell/rice; niri starts it with `qs -c rice`.
{ lib, pkgs, ... }:

{
  # The top pill's visualiser reads cava's raw output while music plays.
  home.packages = [ pkgs.cava ];

  # The raven (RICE_MASCOT=raven) is Umbriel's: its art and moods are copied in
  # from there, so both shells draw it from one source.
  xdg.configFile."quickshell/rice".source = pkgs.runCommand "rice-shell" { } ''
    cp -r ${lib.cleanSourceWith {
      src = ./.;
      filter = path: type: type == "directory" || lib.any (ext: lib.hasSuffix ext path) [ ".qml" ".svg" ".js" ];
    }} $out
    chmod -R u+w $out
    cp ${../umbriel/shell/RavenBody.qml} $out/RavenBody.qml
    cp ${../umbriel/shell/raven-mood.js} $out/raven-mood.js
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
