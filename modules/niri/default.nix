# niri compositor config. The .kdl files here are linked into ~/.config/niri.
# colors.kdl is the exception: rice-wall rewrites it whenever the wallpaper
# changes, so it is a real file, seeded from colors.fallback.kdl when missing.
{ lib, ... }:

let
  files = [
    "config.kdl"
    "input.kdl"
    "layout.kdl"
    "misc.kdl"
    "rules.kdl"
    "binds.kdl"
  ];
in
{
  xdg.configFile = lib.genAttrs (map (f: "niri/${f}") files) (name: {
    source = ./. + "/${lib.removePrefix "niri/" name}";
  });

  home.activation.niriColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/niri/colors.kdl" ]; then
      run install -Dm644 ${./colors.fallback.kdl} "$HOME/.config/niri/colors.kdl"
    fi
  '';
}
