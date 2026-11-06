# NixOS side of the rice: packages and services the desktop needs.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
  ];

  # Password check for the lock screen (modules/lock).
  security.pam.services.rice-lock = { };
}
