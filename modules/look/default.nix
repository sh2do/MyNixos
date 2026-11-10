# How the desktop looks and asks for passwords, in every session: the polkit
# agent, and the cursor, icon, GTK and Qt themes.
{ config, lib, pkgs, ... }:

let
  # qt5ct and qt6ct read the same settings; the palette is matugen's
  # (modules/theme/templates/qtct-colors.conf). QT_QPA_PLATFORMTHEME=qt5ct is
  # set system-wide in configuration.nix (qt6ct answers to that name too).
  qtct = v: lib.generators.toINI { } {
    Appearance = {
      style = "Fusion";
      custom_palette = true;
      color_scheme_path = "${config.xdg.configHome}/${v}/colors/rice.conf";
      icon_theme = "Papirus-Dark";
    };
    Fonts = {
      general = ''"Rubik,11,-1,5,50,0,0,0,0,0"'';
      fixed = ''"JetBrainsMono Nerd Font,11,-1,5,50,0,0,0,0,0"'';
    };
  };
in

{
  # Shows the password prompt when an app asks polkit for admin rights.
  systemd.user.services.polkit-agent = {
    Unit = {
      Description = "polkit authentication agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # One cursor for GTK, Xwayland and the compositors (niri sets it too, in misc.kdl).
  home.pointerCursor = {
    enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # Colours come from matugen (modules/theme/templates/gtk.css), not from here,
  # so no extraCss: that would make Home Manager own gtk.css.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Rubik";
      package = pkgs.rubik;
      size = 11;
    };
  };

  xdg.configFile."qt5ct/qt5ct.conf".text = qtct "qt5ct";
  xdg.configFile."qt6ct/qt6ct.conf".text = qtct "qt6ct";
}
