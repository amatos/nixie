# Gammu-specific home-manager settings for alberth.
# krb5 is provided by nixos.nix for all NixOS hosts.
{ pkgs, ... }:

{
  # Gammu-only packages
  home.packages = [
    pkgs.act # Run GitHub Actions locally
    pkgs.nerdctl # Docker-compatible CLI for containerd
  ];

  # nerdctl — transparent sudo so rootful containerd works as non-root
  programs.fish.shellAliases = {
    nerdctl = "sudo nerdctl";
  };
}
