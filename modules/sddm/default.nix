# Login screen: SDDM with the custom "rice" theme (train landscape video).
# NixOS side; imported from configuration.nix.
{ pkgs, ... }:

let
  rice-sddm-theme = pkgs.stdenvNoCC.mkDerivation {
    pname = "rice-sddm-theme";
    version = "1.0";
    src = ./theme;
    installPhase = ''
      mkdir -p $out/share/sddm/themes/rice
      cp -r ./* $out/share/sddm/themes/rice/
      cp ${./login.mp4} $out/share/sddm/themes/rice/login.mp4
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
  };

  environment.systemPackages = [ rice-sddm-theme ];
}
