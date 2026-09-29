# Edit this configuration file to define what should be installed on


# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:
  
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
       inputs.noctalia.nixosModules.default
    ];
   programs.noctalia = {
    enable = true;
    
    };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  nix.settings.experimental-features=["nix-command" "flakes"];


  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # networking.hostName = "nixos"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
   time.timeZone = "Africa/Nairobi";

  users.users.Zaion ={

  isNormalUser =true;
 description ="Zaion";
 extraGroups =[ "wheel" "networkmanager"];
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
 nixpkgs.config.allowUnfree = true;

  programs.steam.enable = true;
  programs.gamemode.enable = true;
  hardware.graphics.enable32Bit = true;

  programs.thunar.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
programs.niri.enable = true;

environment.systemPackages = with pkgs; [
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
 inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
]; 
 programs.silentSDDM ={
    enable= true;
     theme = "catppuccin-mocha";
  settings = {
    "LockScreen".background-color = "#222222";
    "LockScreen.Clock".color = "#c2c2b0";
    "LockScreen.Date".color = "#c9a554";
    "LoginScreen".background-color = "#222222";
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

   services.xserver.videoDrivers =["nvidia"];
   hardware.nvidia ={
   modesetting.enable = true;
   open = true;
   powerManagement.enable = true;
   nvidiaSettings = true;
   
   prime= { 
   offload ={
   enable = true;
   enableOffloadCmd = true;
   };
   intelBusId = "PCI:0:2:0";
   nvidiaBusId = "PCI:0:1:0";
  };
   };

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.alice = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     tree
  #   ];
  # };

  # programs.firefox.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}

