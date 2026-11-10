# Power and fans for the OMEN 16 (docs/RICE.md, "Power and fans").
#  - rice-power-auto: power-saver when the charger is pulled, the AC profile
#    back when it returns (rice-power-auto.sh). udev starts it on charger
#    events; it also runs at boot and after resume, for a charger that came or
#    went while off or asleep.
#  - rice-fan: fan boost through the patched hp-wmi's hwmon (rice-fan.sh); a
#    udev rule lets the wheel group write pwm1_enable, so no sudo.
{ pkgs, ... }:

let
  rice-power-auto = pkgs.writeShellApplication {
    name = "rice-power-auto";
    runtimeInputs = with pkgs; [ coreutils power-profiles-daemon ];
    text = builtins.readFile ./rice-power-auto.sh;
  };

  rice-fan = pkgs.writeShellApplication {
    name = "rice-fan";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./rice-fan.sh;
  };
in
{
  environment.systemPackages = [ rice-fan ];

  systemd.services.rice-power-auto = {
    description = "Power profile follows the charger";
    after = [ "power-profiles-daemon.service" "post-resume.target" ];
    wants = [ "power-profiles-daemon.service" ];
    wantedBy = [ "multi-user.target" "post-resume.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${rice-power-auto}/bin/rice-power-auto";
      StateDirectory = "rice-power";
    };
  };

  services.udev.extraRules = ''
    # The charger came or went (ADP1, or a USB-C charger): let the profile follow.
    SUBSYSTEM=="power_supply", ACTION=="change", ATTR{type}=="Mains|USB", RUN+="${pkgs.systemd}/bin/systemctl start --no-block rice-power-auto.service"
    # Fan boost without sudo: hp-wmi's pwm1_enable (0 max, 2 auto) for wheel.
    SUBSYSTEM=="hwmon", ACTION=="add", ATTR{name}=="hp", DRIVERS=="hp-wmi", RUN+="${pkgs.coreutils}/bin/chgrp wheel /sys%p/pwm1_enable", RUN+="${pkgs.coreutils}/bin/chmod 0664 /sys%p/pwm1_enable"
  '';
}
