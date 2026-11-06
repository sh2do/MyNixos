# rofi launcher and the rice-menu script (wifi, bluetooth, power, ...).
{ pkgs, ... }:

let
  rice-menu = pkgs.writeShellApplication {
    name = "rice-menu";
    runtimeInputs = with pkgs; [
      rofi
      networkmanager
      bluez
      pulseaudio # pactl, talks to pipewire-pulse
      jq
      power-profiles-daemon
      cliphist
      wl-clipboard
      findutils
      coreutils
    ];
    text = builtins.readFile ./rice-menu.sh;
  };
in
{
  home.packages = [ rice-menu pkgs.rofi ];

  xdg.configFile."rofi/config.rasi".source = ./config.rasi;
  xdg.configFile."rofi/theme.rasi".source = ./theme.rasi;
}
