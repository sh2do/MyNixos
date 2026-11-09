# Login screen: SDDM with the custom "rice" theme (train landscape video).
# NixOS side; imported from configuration.nix.
{ pkgs, ... }:

let
  rice-sddm-theme = pkgs.stdenvNoCC.mkDerivation {
    pname = "rice-sddm-theme";
    version = "1.0";
    src = ./theme;
    nativeBuildInputs = [ pkgs.librsvg ];
    # The card's water (rofi's drips template, and the drops hanging under the
    # card) in theme.conf's fixed colours: the greeter runs before login, so
    # matugen's colours aren't there.
    installPhase = ''
      dir=$out/share/sddm/themes/rice
      mkdir -p $dir
      cp Main.qml metadata.desktop theme.conf $dir/
      cp ${./login.mp4} $dir/login.mp4
      conf() { sed -n "s/^$1=//p" theme.conf; }
      fill() {
        sed -e "s/{{colors.primary.default.hex}}/$(conf primary)/g" \
            -e "s/{{colors.surface.default.hex}}/$(conf surface)/g" \
            -e "s/{{colors.on_surface.default.hex}}/$(conf text)/g" "$1"
      }
      fill ${../theme/templates/drips.svg} > drips.svg
      fill hang.svg > hang-filled.svg
      if grep -q '{{' drips.svg hang-filled.svg; then
        echo "unfilled colour placeholder in the drips" >&2; exit 1
      fi
      rsvg-convert -z 2 drips.svg -o $dir/drips.png
      rsvg-convert -z 2 hang-filled.svg -o $dir/hang.png
    '';
  };
in
{
  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm; # Qt 6, which the theme is written for
    # kwin as the greeter's compositor, as SilentSDDM had it (weston can lose the cursor).
    wayland = {
      enable = true;
      compositor = "kwin";
    };
    theme = "rice";
    # The theme plays a video.
    extraPackages = [ pkgs.kdePackages.qtmultimedia ];
    # Same cursor as the desktop (modules/look).
    settings.Theme = {
      CursorTheme = "Bibata-Modern-Classic";
      CursorSize = 24;
    };
  };

  environment.systemPackages = [ rice-sddm-theme pkgs.bibata-cursors ];
}
