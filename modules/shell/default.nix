# The Quickshell config "rice" (bar, top pill, wallpaper picker).
# Deployed as ~/.config/quickshell/rice; niri starts it with `qs -c rice`.
{ lib, ... }:

{
  xdg.configFile."quickshell/rice".source = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: type == "directory" || lib.any (ext: lib.hasSuffix ext path) [ ".qml" ".svg" ".js" ];
  };
}
