# The real weather for both shells' scenes: rice-weather asks Open-Meteo (no
# key) every 20 minutes and writes ~/.cache/rice/weather.json; the shells read
# it (modules/shell/Weather.qml). Not tied to a session, so it serves niri and
# Umbriel alike. The place: RICE_WEATHER_LAT / RICE_WEATHER_LON in the user
# manager's environment, Nairobi by default.
{ pkgs, ... }:

let
  rice-weather = pkgs.writeShellApplication {
    name = "rice-weather";
    runtimeInputs = with pkgs; [ coreutils curl jq ];
    text = builtins.readFile ./rice-weather.sh;
  };
in
{
  home.packages = [ rice-weather ];

  systemd.user.services.rice-weather = {
    Unit = {
      Description = "Fetch the weather for the shells";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${rice-weather}/bin/rice-weather";
    };
  };

  # Offline, the fetch keeps the last file; the shells drop it after 3 h.
  systemd.user.timers.rice-weather = {
    Unit.Description = "Fetch the weather every 20 minutes";
    Timer = {
      OnActiveSec = "30s"; # from the timer starting: login, or a switch
      OnUnitActiveSec = "20min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
