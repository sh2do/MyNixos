# The Quickshell config "rice" (bar, top pill, wallpaper picker).
# Deployed as ~/.config/quickshell/rice; niri starts it with `qs -c rice`.
{ lib, pkgs, ... }:

{
  xdg.configFile."quickshell/rice".source = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: type == "directory" || lib.any (ext: lib.hasSuffix ext path) [ ".qml" ".svg" ".js" ];
  };

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
