# The lock screen: the Quickshell config "rice-lock" (Tokyo rain video), the
# rice-lock command, and swayidle, which locks after 5 min idle and before sleep
# and turns the monitors off after 10 min (rice-dpms, niri or Umbriel).
# PAM service "rice-lock" lives on the NixOS side (modules/desktop.nix).
{ pkgs, lib, osConfig, ... }:

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

  # Monitors off/on in either session (niri or Umbriel).
  rice-dpms = pkgs.writeShellApplication {
    name = "rice-dpms";
    runtimeInputs = [ pkgs.niri osConfig.programs.umbriel.package ];
    text = builtins.readFile ./rice-dpms.sh;
  };
in
{
  home.packages = [ rice-lock rice-dpms ];

  # The shell's media, phone and weather pieces are copied in, not duplicated.
  xdg.configFile."quickshell/rice-lock".source = pkgs.runCommandLocal "rice-lock-config" { } ''
    cp -r ${lib.cleanSourceWith {
      src = ./.;
      filter = path: type: type == "directory" || lib.hasSuffix ".qml" path
        || lib.hasSuffix ".js" path || lib.hasSuffix ".mp4" path;
    }} $out
    chmod -R u+w $out
    for f in Phone.qml phone.js Weather.qml weather.js media.js; do
      cp ${../shell}/$f $out/$f
    done
  '';

  # -w (the default) waits for rice-lock, which returns once the lock is secure.
  services.swayidle = {
    enable = true;
    timeouts = [
      { timeout = 300; command = lock; }
      { timeout = 600; command = "${rice-dpms}/bin/rice-dpms off"; }
    ];
    events = {
      before-sleep = lock;
      lock = lock;
    };
  };
}
