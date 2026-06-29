# Common packages installed on every host (NixOS and nix-darwin).
{ lib, pkgs, ... }:

{
  # Allow unfree packages fleet-wide (slack, spotify, zoom-us, discord, etc.)
  nixpkgs.config.allowUnfree = true;

  # Binary caches — amatos.cachix.org for devenv and personal builds.
  # trusted-users: wheel-group members are trusted so that flake inputs
  # that declare extra substituters via nixConfig (nix-community, zed,
  # garnix, etc.) are actually used rather than silently ignored.
  nix.settings = {
    substituters = [ "https://amatos.cachix.org" ];
    trusted-public-keys = [ "amatos.cachix.org-1:f8dGcsYmNVdex+prgb03Pu5yCIDkzrB8dp2lmpBfNT4=" ];
    trusted-users = [
      "root"
      "@wheel"
    ];
  };

  environment.systemPackages =
    with pkgs;
    [
      age # age encryption
      age-plugin-yubikey
      cachix # Nix binary cache hosting — push and use build artifacts
      rage # Rust implementation of age
      git
      inkscape # Vector graphics editor
      nh # Nix helper — nicer `nixos-rebuild` / `darwin-rebuild` / `home-manager` UX
    ]
    # ghostty.terminfo: Linux only — on darwin the Homebrew cask installs it automatically
    ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.ghostty.terminfo ];
}
