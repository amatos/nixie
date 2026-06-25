# Common packages installed on every host (NixOS and nix-darwin).
{ lib, pkgs, ... }:

{
  # Allow unfree packages fleet-wide (slack, spotify, zoom-us, discord, etc.)
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages =
    with pkgs;
    [
      age # age encryption
      age-plugin-yubikey
      rage # Rust implementation of age
      git
      inkscape # Vector graphics editor
      nh # Nix helper — nicer `nixos-rebuild` / `darwin-rebuild` / `home-manager` UX
    ]
    # ghostty.terminfo: Linux only — on darwin the Homebrew cask installs it automatically
    ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.ghostty.terminfo ];
}
