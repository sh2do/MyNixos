# Home backups with restic: `rice-backup` (see rice-backup.sh) and a daily
# user timer that runs `rice-backup now`. Nothing happens until
# `rice-backup init <repo>` picks a destination; until then the timer's run
# says so and exits 0.
{ pkgs, ... }:

let
  rice-backup = pkgs.writeShellApplication {
    name = "rice-backup";
    runtimeInputs = with pkgs; [ restic coreutils findutils util-linux jq libnotify ];
    text = builtins.readFile ./rice-backup.sh;
  };
in
{
  home.packages = [ rice-backup ];

  systemd.user.services.rice-backup = {
    Unit = {
      Description = "Back up the home folder with restic";
      # On battery the day's run is skipped; a week without one warns.
      ConditionACPower = true;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${rice-backup}/bin/rice-backup now";
      # phone-alert (home profile) and kdeconnect-cli, ssh for sftp:, and
      # rclone if installed (system profile); restic itself is wrapped in.
      Environment = [ "PATH=/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin:/run/wrappers/bin" ];
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.rice-backup = {
    Unit.Description = "Back up the home folder daily";
    Timer = {
      OnCalendar = "daily";
      Persistent = true; # missed while off or asleep: run soon after
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
