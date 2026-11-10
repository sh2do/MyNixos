{ config, pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    ./hardware-configuration.nix
    ./modules/desktop.nix
    ./modules/sddm
    ./modules/boot # Plymouth splash and quiet boot
    ./modules/gaming # Steam, gamemode, MangoHud, gamescope
    ./modules/power # auto power profile, fan boost (rice-fan)
    inputs.home-manager.nixosModules.default
    inputs.umbriel.nixosModules.default
  ];

  # --------------------------------------------------
  # Desktop environments and sessions
  # --------------------------------------------------

  programs.niri.enable = true;

  # Second session (Home Manager side: modules/umbriel).
  programs.umbriel = {
    enable = true;
    # Required for screen sharing / screenshots through xdg-desktop-portal.
    portalPackage = inputs.xdg-desktop-portal-umbriel.packages.${system}.default;
  };

  # --------------------------------------------------
  # Shell and command-line tools
  # --------------------------------------------------

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set fish_greeting
      rice_first_fetch
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
      ff = "fastfetch";
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

  programs.tmux = {
    enable = true;
    clock24 = true;
    baseIndex = 1; # windows/panes start at 1
    escapeTime = 0; # no Esc delay in nvim
    historyLimit = 50000;
    keyMode = "vi";
    terminal = "tmux-256color";
    aggressiveResize = true;
    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator # Ctrl-h/j/k/l moves between nvim splits and tmux panes
      yank # copy to the system clipboard
      resurrect # prefix + Ctrl-s saves the session, prefix + Ctrl-r restores it
      continuum # autosaves the session and restores it on start
    ];
    extraConfig = ''
      set -g default-shell ${pkgs.fish}/bin/fish
      set -g mouse on
      set -g renumber-windows on
      set -g set-clipboard on
      set -ag terminal-overrides ",xterm-ghostty:RGB,xterm-256color:RGB"
      set -g @continuum-restore 'on'

      # Split panes in the current directory with | and -
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
      bind r source-file /etc/tmux.conf \; display "tmux config reloaded"

      # vi-style copy mode
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-selection-and-cancel

      # Simple status bar
      set -g status-position top
      set -g status-style "bg=default,fg=white"
      set -g status-left "#[bold] #S  "
      set -g status-right "%H:%M "
      set -g window-status-current-style "fg=cyan,bold"
    '';
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
    ls = "eza --icons=auto";
    ll = "eza -l --icons=auto --git";
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

  # Patched hp-wmi with Omen keyboard/lightbar RGB LEDs (for omen-rgb-linux)
  boot.extraModulePackages = [
    (config.boot.kernelPackages.callPackage ./hp-wmi-omen.nix { })
  ];

  nixpkgs.config.allowUnfree = true;

  # --------------------------------------------------
  # Networking, Bluetooth and user
  # --------------------------------------------------

  networking.networkmanager.enable = true;

  # The phone link: KDE Connect (kdeconnectd, kdeconnect-cli). It opens TCP and
  # UDP 1714-1764 in the (default, enabled) firewall; the phone finds this
  # machine by broadcast on the same Wi-Fi, and only paired devices are
  # trusted. Both sessions start the daemon (niri's config.kdl, Umbriel's
  # autostart); the bar and phone-alert talk to it.
  programs.kdeconnect.enable = true;

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
  # Graphics (Steam, gamemode and the rest: modules/gaming)
  # --------------------------------------------------

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
    # Runtime D3: the dGPU powers off when nothing uses it (needs PRIME offload).
    powerManagement.finegrained = true;
    nvidiaSettings = true;
    # "latest" = newest driver branch; switch back to .stable if anything breaks
    package = config.boot.kernelPackages.nvidiaPackages.latest;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };

      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0"; # 01:00.0; 00:01.0 is the PCIe bridge above it
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
  # App colours (rice-wall/matugen writes the files; see docs/RICE.md)
  # --------------------------------------------------

  # Qt 5 and 6 apps take qt5ct/qt6ct's palette (modules/look). Set through PAM
  # (sessionVariables) as well as the shell profile, so the niri and Umbriel
  # sessions both see it, whatever starts them.
  qt = {
    enable = true;
    platformTheme = "qt5ct"; # installs qt5ct and qt6ct; qt6ct answers to qt5ct too
  };
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "qt5ct";

  # Firefox loads the matugen userChrome/userContent that rice-wall copies into
  # each profile only with this preference on. "default", not locked.
  programs.firefox = {
    enable = true;
    preferences."toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    preferencesStatus = "default";
  };

  # --------------------------------------------------
  # Packages
  # --------------------------------------------------

  environment.systemPackages = with pkgs; [
    # Existing applications (firefox comes from programs.firefox above)
    # Discord with the Vencord client mod, for the matugen theme
    # (~/.config/Vencord/themes/rice.css). Still `discord` for Super+Z.
    (discord.override { withVencord = true; })
    ghostty
    foot
    git
    kitty
    bat
    neovim
    xwayland-satellite
    fastfetch
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

    # Shell and development tools
    # (fish, zoxide, nh and tmux come from their programs.* options above)
    lazygit
    yazi
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
    matugen # wallpaper-based colour themes

    # File manager (replaces Thunar)
    nautilus
    file-roller # archive support in Nautilus
    ffmpegthumbnailer # video thumbnails

    # Audio and device controls
    pwvucontrol
    bluetuith
    brightnessctl
    ddcutil
    lm_sensors
    cava
    aubio

    # Shell runtime helpers (Quickshell runs the bar and lock screen)
    quickshell
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

    # Python development (used by the LazyVim python extra)
    (python3.withPackages (ps: with ps; [
      pip
      debugpy # provides debugpy-adapter for nvim-dap-python
      pytest
      tkinter # needed by omen-rgb-gui
    ]))
    uv # fast venv / package manager
    pyright # Python language server
    ruff # Python linter + formatter (also an LSP)

    # Neovim build/runtime deps (treesitter parsers, Mason)
    gcc
    gnumake
    tree-sitter
    nodejs
    unzip
    curl
  ];

  # Lets prebuilt binaries (e.g. ones Mason downloads) run on NixOS
  programs.nix-ld.enable = true;

  # --------------------------------------------------
  # Home Manager
  # --------------------------------------------------

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    backupFileExtension = "backup";

    users.Zaion = {
      imports = [ ./modules/home.nix ];

      home.stateVersion = "26.05";

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

  # Custom video theme: modules/sddm.

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

