# The lock screen: the Quickshell config "rice-lock" (Tokyo rain video), the
# rice-lock command, and swayidle, which locks after 5 min idle and before sleep.
# PAM service "rice-lock" lives on the NixOS side (modules/desktop.nix).
{ pkgs, lib, ... }:

let
  qtmultimedia = pkgs.kdePackages.qtmultimedia;

  rice-lock = pkgs.writeShellApplication {
    name = "rice-lock";
    runtimeInputs = with pkgs; [ quickshell util-linux coreutils ];
    # Quickshell doesn't ship QtMultimedia; only the lock needs it.
    # The texture switch silences VA-API export failures and saves a little CPU.
    runtimeEnv = {
      QML_IMPORT_PATH = "${qtmultimedia}/lib/qt-6/qml";
      QT_PLUGIN_PATH = "${qtmultimedia}/lib/qt-6/plugins";
      QT_DISABLE_HW_TEXTURES_CONVERSION = "1";
    };
    text = builtins.readFile ./rice-lock.sh;
  };
  lock = "${rice-lock}/bin/rice-lock";
in
{
  home.packages = [ rice-lock ];

  xdg.configFile."quickshell/rice-lock".source = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: type == "directory" || lib.hasSuffix ".qml" path || lib.hasSuffix ".mp4" path;
  };

  # -w (the default) waits for rice-lock, which returns once the lock is secure.
  services.swayidle = {
    enable = true;
    timeouts = [
      { timeout = 300; command = lock; }
      { timeout = 600; command = "${pkgs.niri}/bin/niri msg action power-off-monitors"; }
    ];
    events = {
      before-sleep = lock;
      lock = lock;
    };
  };
}
