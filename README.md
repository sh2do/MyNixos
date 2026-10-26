# MyNixos

NixOS flake config: niri + Noctalia / Umbriel / DMS, NVIDIA, SilentSDDM, Home Manager.

## Layout

```
flake.nix / flake.lock        flake entry point (host: nixos)
configuration.nix             system + home-manager config
hardware-configuration.nix    generated hardware config
umbriel-extras/               quickshell config (deployed via home-manager)
greeter.mp4                   SDDM login/lock background
wallpaper.mp4                 desktop wallpaper
dotfiles/                     ghostty, niri, nvim configs (copied from ~/.config)
```

## Rebuild

```sh
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

## Fresh install

```sh
git clone git@github.com:sh2do/MyNixos.git /etc/nixos
sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```
