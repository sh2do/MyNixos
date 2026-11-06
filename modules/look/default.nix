# How the desktop looks and asks for passwords, in every session: the polkit
# agent, and the cursor, icon and GTK themes.
{ pkgs, ... }:

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
}
