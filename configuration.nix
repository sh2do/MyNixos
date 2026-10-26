{ config, pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;

  # --------------------------------------------------
  # "Niri + DMS" login session
  # --------------------------------------------------
  # Same idea as the old Caelestia session: a second entry in the login
  # screen that starts niri with its own config file (~/.config/niri/dms.kdl,
  # managed in the Home Manager block below). The regular "niri" session keeps
  # using config.kdl + Noctalia.
  niriDmsStart = pkgs.writeShellScript "niri-dms-session" ''
    export NIRI_CONFIG="$HOME/.config/niri/dms.kdl"
    ${pkgs.niri}/bin/niri-session
    # Do not leak the override into the next session of this user manager.
    systemctl --user unset-environment NIRI_CONFIG
  '';

  niriDmsSession =
    (pkgs.writeTextDir "share/wayland-sessions/niri-dms.desktop" ''
      [Desktop Entry]
      Name=Niri + DMS
      Comment=Niri running DankMaterialShell
      Exec=${niriDmsStart}
      Type=Application
    '').overrideAttrs
      (_: {
        passthru.providedSessions = [ "niri-dms" ];
      });

  # --------------------------------------------------
  # Extra Quickshell widgets for the Umbriel session
  # --------------------------------------------------
  # Noctalia is the Umbriel desktop shell. This is a small Quickshell config
  # that sits next to it (config dir: ./umbriel-extras, deployed to
  # ~/.config/quickshell/umbriel-extras). The wrapper uses absolute store
  # paths so Umbriel's autostart works even with a minimal PATH.
  umbrielExtras = pkgs.writeShellScriptBin "umbriel-extras" ''
    exec ${pkgs.quickshell}/bin/qs -c umbriel-extras
  '';
in
{
  imports = [
    # Keep any other imports your original list had above this line
    # (for example the silentSDDM module).
    ./hardware-configuration.nix
    inputs.noctalia.nixosModules.default
    inputs.umbriel.nixosModules.default
    inputs.dms.nixosModules.dank-material-shell
    inputs.home-manager.nixosModules.default
  ];

  # --------------------------------------------------
  # Desktop environments and sessions
  # --------------------------------------------------

  programs.niri.enable = true;
  programs.noctalia.enable = true;

  programs.umbriel = {
    enable = true;
    # Required for screen sharing / screenshots through xdg-desktop-portal.
    portalPackage = inputs.xdg-desktop-portal-umbriel.packages.${system}.default;
  };

  # DankMaterialShell. It is started by the "Niri + DMS" session only
  # (spawn-at-startup in dms.kdl). Do NOT turn on systemd.enable here: that
  # would also start DMS inside the Noctalia niri session and the Umbriel one.
  programs.dank-material-shell = {
    enable = true;
    enableSystemMonitoring = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
  };

  # Extra login session next to the regular Niri one.
  services.displayManager.sessionPackages = [
    niriDmsSession
  ];

  # --------------------------------------------------
  # Shell and command-line tools
  # --------------------------------------------------

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set fish_greeting
      fastfetch
      ${pkgs.nix-your-shell}/bin/nix-your-shell fish | source
    '';

    shellAbbrs = {
      rebuild = "nh os switch";
      update = "nh os switch --update";
      g = "git";
      gs = "git status";
      gc = "git commit";
      gp = "git push";
      lg = "lazygit";
      v = "nvim";
    };
  };

  programs.starship.enable = true;
  programs.zoxide.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };

  programs.nh = {
    enable = true;
    flake = "/etc/nixos";

    clean = {
      enable = true;
      extraArgs = "--keep-since 7d --keep 5";
    };
  };

  environment.shellAliases = {
    ls = "eza --icons";
    ll = "eza -l --icons --git";
    cat = "bat";
  };

  # --------------------------------------------------
  # Boot and Nix
  # --------------------------------------------------

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10; # keep /boot from filling up

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true; # hardlink identical store files

  zramSwap.enable = true; # compressed in-RAM swap

  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.config.allowUnfree = true;

  # --------------------------------------------------
  # Networking, Bluetooth and user
  # --------------------------------------------------

  networking.networkmanager.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.blueman.enable = true;

  time.timeZone = "Africa/Nairobi";
  i18n.defaultLocale = "en_US.UTF-8";

  services.fwupd.enable = true; # firmware updates via fwupdmgr

  users.users.Zaion = {
    isNormalUser = true;
    description = "Zaion";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.fish;
  };

  # --------------------------------------------------
  # Gaming and graphics
  # --------------------------------------------------

  programs.steam = {
    enable = true;

    extraCompatPackages = with pkgs; [
      dwproton-bin
      proton-ge-bin
    ];
  };

  programs.gamemode.enable = true;
  hardware.graphics.enable32Bit = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
    nvidiaSettings = true;
    # "latest" = newest driver branch; switch back to .stable if anything breaks
    package = config.boot.kernelPackages.nvidiaPackages.latest;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };

      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:0:1:0";
    };
  };

  # --------------------------------------------------
  # File management and media
  # --------------------------------------------------

  # Nautilus (GNOME Files) replaces Thunar. It needs gvfs and dconf.
  programs.dconf.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  services.gnome.sushi.enable = true; # press Space to preview files

  # --------------------------------------------------
  # Fonts
  # --------------------------------------------------

  fonts.packages = with pkgs; [
    material-symbols
    rubik
    nerd-fonts.caskaydia-cove
    nerd-fonts.jetbrains-mono
  ];

  # --------------------------------------------------
  # Packages
  # --------------------------------------------------

  environment.systemPackages = with pkgs; [
    # Existing applications
    firefox
    discord
    ghostty
    foot
    git
    zsh
    kitty
    bat
    neovim
    xwayland-satellite
    fetch
    fastfetch
    mpvpaper
    myx
    eza
    spotify
    imv
    btop
    ripgrep
    fd
    fzf
    gh

    # Existing flake applications
    inputs.antigravity-nix.packages.${system}.default
    inputs.antigravity-nix.packages.${system}.google-antigravity-ide
    inputs.antigravity-nix.packages.${system}.google-antigravity-cli

    inputs.noctalia.packages.${system}.default
    inputs.umbriel.packages.${system}.default

    # Shell and development tools
    # (fish, zoxide and nh come from their programs.* options above)
    lazygit
    yazi
    tmux
    nvd
    nix-output-monitor # readable build progress (nom)
    jq
    file
    nix-index
    comma
    nixfmt
    ni

    # Config management: Nix editing, linting and inspection
    nixd # Nix language server for nvim
    statix # lints Nix code
    deadnix # finds unused Nix code
    nix-tree # browse what takes space in the system

    # Config management: appearance and settings
    dconf-editor # GTK/GNOME settings editor
    nwg-look # GTK theme, icon and cursor picker
    matugen # wallpaper-based colour themes

    # File manager (replaces Thunar)
    nautilus
    file-roller # archive support in Nautilus
    ffmpegthumbnailer # video thumbnails

    # Gaming utilities
    mangohud
    protonup-qt

    # Audio and device controls
    pwvucontrol
    bluetuith
    brightnessctl
    ddcutil
    lm_sensors
    cava
    aubio

    # Shell runtime helpers (used by DMS, Noctalia and the Umbriel extras)
    quickshell
    umbrielExtras
    grim
    swappy
    wl-clipboard
    cliphist

    # Qt and editor applications
    kdePackages.kate
    kdePackages.ktexteditor

    # Themes and icons
    adwaita-icon-theme
    papirus-icon-theme

    #Cli and other ai tools
    claude-code
  ];

  # --------------------------------------------------
  # Home Manager
  # --------------------------------------------------

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    backupFileExtension = "backup";

    users.Zaion = {
      imports = [ inputs.umbriel.homeModules.default ];

      home.stateVersion = "26.05";

      # ------------------------------------------------
      # Niri + DMS session config
      # ------------------------------------------------
      # Managed here so the file always exists (niri silently ignores a
      # missing config path). Used only by the "Niri + DMS" login session.
      #
      # IMPORTANT: common.kdl must NOT spawn Noctalia or any other shell, or
      # two shells will start in this session. Keep each shell's
      # spawn-at-startup in its own file (config.kdl for Noctalia, this file
      # for DMS) and put binds, layout and input in common.kdl.
      #
      # Check it after changes with:
      #   niri validate --config ~/.config/niri/dms.kdl
      xdg.configFile."niri/dms.kdl".text = ''
        include "common.kdl"

        spawn-at-startup "dms" "run"

        binds {
            Mod+Space repeat=false { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
            Mod+Alt+C repeat=false { spawn "dms" "ipc" "call" "control-center" "toggle"; }
            Mod+Alt+N repeat=false { spawn "dms" "ipc" "call" "notifications" "toggle"; }
            Mod+Alt+V repeat=false { spawn "dms" "ipc" "call" "clipboard" "toggle"; }
            Mod+Alt+S repeat=false { spawn "dms" "ipc" "call" "settings" "toggle"; }
            Mod+Alt+P repeat=false { spawn "dms" "ipc" "call" "powermenu" "toggle"; }
            Mod+Alt+L repeat=false { spawn "dms" "ipc" "call" "lock" "lock"; }
            Ctrl+Alt+Delete repeat=false { spawn "dms" "ipc" "call" "processlist" "toggle"; }

            Print repeat=false { spawn "dms" "ipc" "call" "niri" "screenshot"; }
            Ctrl+Print repeat=false { spawn "dms" "ipc" "call" "niri" "screenshotScreen"; }
            Alt+Print repeat=false { spawn "dms" "ipc" "call" "niri" "screenshotWindow"; }

            XF86AudioRaiseVolume allow-when-locked=true { spawn "dms" "ipc" "call" "audio" "increment" "5"; }
            XF86AudioLowerVolume allow-when-locked=true { spawn "dms" "ipc" "call" "audio" "decrement" "5"; }
            XF86AudioMute allow-when-locked=true { spawn "dms" "ipc" "call" "audio" "mute"; }
            XF86MonBrightnessUp allow-when-locked=true { spawn "dms" "ipc" "call" "brightness" "increment" "5" ""; }
            XF86MonBrightnessDown allow-when-locked=true { spawn "dms" "ipc" "call" "brightness" "decrement" "5" ""; }
        }
      '';

      # ------------------------------------------------
      # Umbriel session: compositor config + extras
      # ------------------------------------------------
      # Noctalia writes ~/.config/umbriel/noctalia.toml (theme colours). Since
      # config.toml is read-only here, it is pulled in through an optional
      # include instead of Noctalia editing config.toml itself.
      #
      # Check keys with:  umbriel config validate
      programs.umbriel = {
        enable = true;

        settings = {
          include.optional.files = [ "~/.config/umbriel/noctalia.toml" ];

          general.autostart = [
            "noctalia"
            "${umbrielExtras}/bin/umbriel-extras"
          ];

          appearance.blur.radius = 3;
          input.keyboard.numlock_toggle = true;

          layout = {
            extent_presets = [
              0.333
              0.5
              0.667
            ];
            scrolling.default_extent_fraction = 0.5;
          };

          # Defining this table replaces Umbriel's built-in binds, so the
          # whole working set is listed.
          keybinds = {
            # Applications and session
            "Mod+Return" = {
              action = "spawn:ghostty";
              repeat = false;
            };
            "Mod+Q" = {
              action = "window-close";
              repeat = false;
            };
            "Mod+Escape" = "session-quit";
            "Mod+Shift+Escape" = {
              action = "shortcuts-inhibit-toggle";
              allow_when_inhibited = true;
              repeat = false;
            };

            # Noctalia
            "Mod" = "spawn:noctalia msg panel-toggle launcher";
            "Mod+S" = "spawn:noctalia msg panel-toggle control-center";
            "Mod+V" = "spawn:noctalia msg panel-toggle clipboard";
            "Mod+W" = "spawn:noctalia msg panel-toggle wallpaper";
            "Mod+Shift+E" = "spawn:noctalia msg panel-toggle session";
            "Mod+Ctrl+Comma" = "spawn:noctalia msg settings-toggle";
            "Print" = "spawn:noctalia msg screenshot-region";
            "XF86AudioRaiseVolume" = "spawn:noctalia msg volume-up";
            "XF86AudioLowerVolume" = "spawn:noctalia msg volume-down";
            "XF86AudioMute" = "spawn:noctalia msg volume-mute";
            "XF86MonBrightnessUp" = "spawn:noctalia msg brightness-up";
            "XF86MonBrightnessDown" = "spawn:noctalia msg brightness-down";

            # Umbriel extras (Quickshell): toggle the system stats card
            "Mod+I" = "spawn:${pkgs.quickshell}/bin/qs -c umbriel-extras ipc call stats toggle";

            # Focus and movement
            "Mod+Left" = "window-focus-left";
            "Mod+Down" = "window-focus-down";
            "Mod+Up" = "window-focus-up";
            "Mod+Right" = "window-focus-right";
            "Mod+H" = "window-focus-left";
            "Mod+J" = "window-focus-down";
            "Mod+K" = "window-focus-up";
            "Mod+L" = "window-focus-right";
            "Mod+F1" = "window-focus-next";
            "Mod+Shift+Left" = "column-move-left";
            "Mod+Shift+Down" = "window-move-down";
            "Mod+Shift+Up" = "window-move-up";
            "Mod+Shift+Right" = "column-move-right";

            # Window state and layout
            "Mod+T" = {
              action = "window-toggle-floating";
              repeat = false;
            };
            "Mod+Shift+T" = {
              action = "window-focus-switch-floating";
              repeat = false;
            };
            "Mod+P" = {
              action = "window-toggle-pinned";
              repeat = false;
            };
            "Mod+M" = {
              action = "window-toggle-maximize-to-edges";
              repeat = false;
            };
            "Mod+F" = {
              action = "window-toggle-fullscreen";
              repeat = false;
            };
            "Mod+Ctrl+F" = {
              action = "window-toggle-maximize";
              repeat = false;
            };
            "Mod+R" = "window-cycle-primary-extent";
            "Mod+Shift+R" = "window-cycle-primary-extent-back";
            "Mod+Comma" = "window-consume-left";
            "Mod+Period" = "window-consume-right";
            "Mod+WheelUp" = "window-focus-left";
            "Mod+WheelDown" = "window-focus-right";
            "Mod+O" = {
              action = "overview-toggle";
              repeat = false;
            };

            # Workspaces
            "Mod+1" = "workspace-switch:1";
            "Mod+2" = "workspace-switch:2";
            "Mod+3" = "workspace-switch:3";
            "Mod+4" = "workspace-switch:4";
            "Mod+5" = "workspace-switch:5";
            "Mod+6" = "workspace-switch:6";
            "Mod+7" = "workspace-switch:7";
            "Mod+8" = "workspace-switch:8";
            "Mod+9" = "workspace-switch:9";
            "Mod+Shift+1" = "window-move-to-workspace:1";
            "Mod+Shift+2" = "window-move-to-workspace:2";
            "Mod+Shift+3" = "window-move-to-workspace:3";
            "Mod+Shift+4" = "window-move-to-workspace:4";
            "Mod+Shift+5" = "window-move-to-workspace:5";
            "Mod+Shift+6" = "window-move-to-workspace:6";
            "Mod+Shift+7" = "window-move-to-workspace:7";
            "Mod+Shift+8" = "window-move-to-workspace:8";
            "Mod+Shift+9" = "window-move-to-workspace:9";

            # Scratchpad
            "Mod+Shift+Space" = {
              action = "window-move-to-scratchpad";
              repeat = false;
            };
            "Mod+Space" = "scratchpad-toggle";
            "Mod+Ctrl+Space" = {
              action = "window-restore-from-scratchpad";
              repeat = false;
            };
            "Mod+Tab" = "scratchpad-focus-next";
          };

          hot_corners.top_left = {
            enabled = true;
            delay_ms = 500;
            action = "overview-open";
          };

          window_rule = [
            {
              blur = true;
              blur_optimized = false;
            }
            {
              match.app_id = "^dev.noctalia.Noctalia$";
              default_floating = true;
              default_floating_size_px = {
                width = 1020;
                height = 900;
              };
            }
            {
              match.app_id = "^dev.noctalia.UmbrielSharePicker$";
              default_floating = true;
              default_floating_size_px = {
                width = 800;
                height = 600;
              };
            }
            {
              match.title = "^(Picture-in-Picture|Picture in picture)$";
              default_floating = true;
              default_maximize = false;
              default_position = {
                x = 20;
                y = 20;
                anchor = "bottom_right";
              };
            }
            {
              match.title = "^notificationtoasts_.+_desktop";
              default_position = {
                x = 0;
                y = 0;
                anchor = "bottom_right";
              };
              default_focused = false;
              default_pinned = true;
            }
          ];

          layer_rule = [
            {
              match.namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd|desktop-widget-[^\"]*)$";
              blur = true;
              blur_ignore_alpha = 0.5;
              blur_popups = true;
              blur_optimized = false;
            }
            {
              # Quickshell extras (see umbriel-extras/shell.qml)
              match.namespace = "^umbriel-extras-.*$";
              blur = true;
              blur_ignore_alpha = 0.5;
              blur_optimized = false;
            }
          ];
        };
      };

      # Quickshell config for the Umbriel extras. Edit the files in
      # ./umbriel-extras, then rebuild; Quickshell live-reloads on change.
      xdg.configFile."quickshell/umbriel-extras".source = ./umbriel-extras;

      # Dark mode for GTK apps such as Nautilus.
      dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

      # Open folders in Nautilus by default.
      xdg.mimeApps = {
        enable = true;
        defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop";
      };
    };
  };

  # --------------------------------------------------
  # Display manager
  # --------------------------------------------------

  programs.silentSDDM = {
    enable = true;
    theme = "catppuccin-mocha";

    backgrounds.wallpaper = ./greeter.mp4;

    settings = {
      "General".enable-animations = true;

      "LockScreen".background = "greeter.mp4";
      "LockScreen".use-background-color = false;

      "LoginScreen".background = "greeter.mp4";
      "LoginScreen".use-background-color = false;

      "LockScreen.Clock".color = "#c2c2b0";
      "LockScreen.Date".color = "#c9a554";

      "LoginScreen.LoginArea.Avatar" = {
        active-border-color = "#c9a554";
        inactive-border-color = "#685742";
      };

      "LoginScreen.LoginArea.Username".color = "#c2c2b0";

      "LoginScreen.LoginArea.PasswordInput" = {
        content-color = "#c2c2b0";
        background-color = "#333333";
        border-color = "#685742";
      };

      "LoginScreen.LoginArea.LoginButton" = {
        background-color = "#333333";
        active-background-color = "#c9a554";
        content-color = "#c9a554";
        active-content-color = "#222222";
        border-color = "#c9a554";
      };

      "LoginScreen.MenuArea.Session".background-color = "#c9a554";
      "LoginScreen.MenuArea.Power".background-color = "#c9a554";
    };
  };

  services.displayManager.sddm.extraPackages = [
    pkgs.kdePackages.qtmultimedia
  ];

  # --------------------------------------------------
  # Audio and power management
  # --------------------------------------------------

  security.rtkit.enable = true; # realtime scheduling for pipewire

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # 32-bit games (Steam)
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  # Release this system was first installed with. Do not bump on upgrades.
  system.stateVersion = "26.05";
}

