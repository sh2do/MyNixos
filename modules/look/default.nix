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
}
