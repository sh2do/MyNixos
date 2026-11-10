# Wallpapers and colours. rice-wall shows a wallpaper with awww and runs
# matugen, which rewrites every themed file listed in matugen.toml.
# The awww daemon, the restore and the rotation belong to the niri session
# only, so they hang off niri.service rather than graphical-session.target
# (which Umbriel starts too).
{ config, lib, pkgs, ... }:

let
  wallhaven = name: hash: pkgs.fetchurl {
    url = "https://w.wallhaven.cc/full/${builtins.substring 0 2 name}/wallhaven-${name}";
    inherit hash;
  };

  # The rotation: rainy, purple and blue.
  rotation = {
    "xe9223.jpg" = "sha256-UKyiVtqLEQSs2W3os/9hMC/LYEbXEDQVl0FBaCIRRho="; # rain + hydrangea
    "3kql73.jpg" = "sha256-RdnWy9MaSujwmxTP/MheUFTFby5U+6RhaPzfgX4LyLo="; # purple hydrangea
    "dpo88l.jpg" = "sha256-JDYSCnE8jjoySmwCi2gqHPNeyCqJmCJHosbH3Sif2H4="; # purple rainy street
    "rr8vx7.jpg" = "sha256-map1l3M00Qx2dLhkE1MWFoSxDwuJnCqM3fUHUPoag18="; # purple rainy street
    "x6kvq3.png" = "sha256-Eivfy383hnbxA+VIykrqsBBIGnMUR3ck9lRd+g0T40Y="; # dusk town
    "xe93pd.png" = "sha256-zljXrkEDER0gNl7SSnAVQlhjsfTToHcAgosdnJVBEyI="; # purple landscape
  };

  # Kept for the wallpaper picker, outside the rotation.
  saved = {
    "gwm1dq.jpg" = "sha256-8EhkDr5ZOtpISn1i8BiKzPCVSMtJM+D9cyxeQrSwIuQ="; # golden ruins
    "gwm1d7.jpg" = "sha256-dxPxugwmrVSNtrD0uo0C6pHbwmSeiIYs3srtKvR5wcY="; # golden ruins
    "jeyo1m.jpg" = "sha256-PS9kJhMk6B0Mg6jRKI/UCbyKmaihpgbv+YuUBIzKE2o="; # ruins and nature
    "k8z1dq.png" = "sha256-R+QpbdFq8MUmh3/GQQjBohvN9TocFaTdHZuVIwubMoo="; # misty courtyard
    "9ogj2d.jpg" = "sha256-s8y9xMK1BJpCumaQOyJctgo0uD423rtEadVYBzPopMA="; # swamp settlement
    "w5x266.jpg" = "sha256-+p1d5OPx1jOSBb7hss683zDJSKEIR1Cyzj/Mvn6oTRI="; # overgrown city
    "zpp6mw.jpg" = "sha256-Sy6ghUsDPQbFjVsMnA2E2C3G9n6KJGMpBgieQoL5tEQ="; # ruined city
    "m39z39.jpg" = "sha256-r0rU4Wcbx/v7hGD0ncDch2R2MVLO2WyEYyWI22rHmcg="; # purple rain
    "v9qy9l.jpg" = "sha256-3Yo3qdzMRQGh/C3Qo5gpS2V1D4u1MptmqsXb+QO9EsE="; # rainy street at night
    "oxzo55.png" = "sha256-tUbJqyQdQaQuNQHz793RJxNIiI2tEuwu18rxfHIp3vA="; # rainy street at night
    "m9rmw1.jpg" = "sha256-IaxvKKgAHRCJP1PvTsAU+igGMJ6SoLq5ZaYvSbHYFJM="; # hydrangeas
    "nerwor.jpg" = "sha256-XSG1hPVkxbvwH1I9HROx7H9hzeIS46tWhxMKDfp0jxg="; # hydrangeas
  };

  wallFiles = dir: set: lib.mapAttrs' (name: hash:
    lib.nameValuePair ".local/share/wallpapers/${dir}/${name}" { source = wallhaven name hash; }
  ) set;

  rice-wall = pkgs.writeShellApplication {
    name = "rice-wall";
    runtimeInputs = with pkgs; [ awww matugen coreutils findutils librsvg gnugrep jq procps ];
    text = builtins.readFile ./rice-wall.sh;
  };

  # awww-daemon takes a moment to accept commands after it starts.
  waitForAwww = pkgs.writeShellScript "wait-for-awww" ''
    for _ in $(seq 50); do
      ${pkgs.awww}/bin/awww query >/dev/null 2>&1 && exit 0
      sleep 0.1
    done
    exit 1
  '';
in
{
  home.packages = [ rice-wall ];

  home.file = wallFiles "rotation" rotation // wallFiles "saved" saved;

  xdg.configFile."matugen/config.toml".source = ./matugen.toml;
  xdg.configFile."matugen/templates".source = ./templates;

  systemd.user.services.awww = {
    Unit = {
      Description = "awww wallpaper daemon";
      PartOf = [ "niri.service" ];
      After = [ "niri.service" ];
    };
    Service = {
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "niri.service" ];
  };

  # Put the last wallpaper back after login.
  systemd.user.services.rice-wall-restore = {
    Unit = {
      Description = "Restore the current wallpaper";
      Requires = [ "awww.service" ];
      After = [ "awww.service" ];
      PartOf = [ "niri.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStartPre = "${waitForAwww}";
      ExecStart = "${pkgs.bash}/bin/bash -c '${rice-wall}/bin/rice-wall init && ${rice-wall}/bin/rice-wall set \"$(${rice-wall}/bin/rice-wall current)\"'";
    };
    Install.WantedBy = [ "niri.service" ];
  };

  systemd.user.services.rice-wall-rotate = {
    Unit.Description = "Show the next wallpaper";
    Service = {
      Type = "oneshot";
      ExecStart = "${rice-wall}/bin/rice-wall next";
    };
  };

  systemd.user.timers.rice-wall-rotate = {
    Unit = {
      Description = "Rotate the wallpaper every 45 minutes";
      PartOf = [ "niri.service" ];
      After = [ "niri.service" ];
    };
    Timer = {
      OnActiveSec = "45min"; # from niri start, not user-manager start
      OnUnitActiveSec = "45min";
    };
    Install.WantedBy = [ "niri.service" ];
  };

  # Generate colours on the first switch so everything starts themed, and again
  # whenever the templates change, so newly themed apps (Qt, Firefox, Vencord,
  # kitty) get their files without waiting for the next wallpaper.
  home.activation.riceColours = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    old=$(readlink -f "''${oldGenPath:-/nonexistent}/home-files/.config/matugen/templates" || true)
    new=$(readlink -f "$newGenPath/home-files/.config/matugen/templates")
    oldConf=$(readlink -f "''${oldGenPath:-/nonexistent}/home-files/.config/matugen/config.toml" || true)
    newConf=$(readlink -f "$newGenPath/home-files/.config/matugen/config.toml")
    if [ ! -s "${config.xdg.cacheHome}/rice/current" ] || [ "$old" != "$new" ] || [ "$oldConf" != "$newConf" ]; then
      run ${rice-wall}/bin/rice-wall init || true
    fi
  '';
}
