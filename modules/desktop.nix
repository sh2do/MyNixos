# NixOS side of the rice: packages and services the desktop needs.
{ ... }:

{
  # Password check for the lock screen (modules/lock).
  security.pam.services.rice-lock = { };
}
