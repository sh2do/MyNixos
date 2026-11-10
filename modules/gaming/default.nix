# Gaming (NixOS side; docs/RICE.md, Gaming). The NVIDIA driver and PRIME
# offload live with the graphics in configuration.nix; the shells' calm while
# a game runs is Game.qml (modules/shell); MangoHud's colours are a matugen
# template (modules/theme/templates/MangoHud.conf).
{ config, pkgs, ... }:

let
  # gamemode's start and end scripts: performance while a game runs, then
  # the profile from before, all through powerprofilesctl. gamemoded's PATH
  # is only pkexec, so everything it needs comes from here.
  rice-game-power = pkgs.writeShellApplication {
    name = "rice-game-power";
    runtimeInputs = [ pkgs.coreutils config.services.power-profiles-daemon.package ];
    text = builtins.readFile ./rice-game-power.sh;
  };
in
{
  programs.steam = {
    enable = true;

    extraCompatPackages = with pkgs; [
      dwproton-bin
      proton-ge-bin
    ];

    # Games on the NVIDIA GPU, the desktop on the Intel one. Steam passes its
    # environment to every game, so Vulkan there (Proton's DXVK and VKD3D,
    # native Vulkan games) sees only the discrete GPU (Mesa's device-select
    # layer). OpenGL is left alone: Steam's own window stays on the iGPU and
    # the dGPU can sleep while Steam idles in the tray. A native OpenGL game
    # needs `nvidia-offload %command%` in its launch options.
    package = pkgs.steam.override {
      extraEnv = {
        MESA_VK_DEVICE_SELECT = "discrete";
        MESA_VK_DEVICE_SELECT_FORCE_DEFAULT_DEVICE = "1";
      };
    };
  };

  # Games started with `gamemoderun` (launch options: docs/RICE.md).
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10; # the game at nice -10 (gamemoded has CAP_SYS_NICE)
        inhibit_screensaver = 1;
        # intel_pstate's own governor, i.e. leave it: the speed comes from
        # power-profiles-daemon's performance profile (rice-game-power), and
        # two writers of the CPU's power policy would fight.
        desiredgov = "powersave";
        igpu_desiredgov = "powersave";
      };
      custom = {
        start = "${rice-game-power}/bin/rice-game-power start";
        end = "${rice-game-power}/bin/rice-game-power end";
      };
    };
  };

  # Optional: a nested compositor for a fixed resolution or frame cap
  # (launch line in docs/RICE.md). No capSysNice: it breaks inside Steam.
  programs.gamescope.enable = true;

  hardware.graphics.enable32Bit = true;

  environment.systemPackages = with pkgs; [
    mangohud # also mangoapp, for gamescope --mangoapp
    protonup-qt
  ];
}
