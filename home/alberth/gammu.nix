# Gammu-specific home-manager settings for alberth.
{ pkgs, ... }:

{
  # Gammu-only packages
  home.packages = [
    pkgs.act # Run GitHub Actions locally
    pkgs.nerdctl # Docker-compatible CLI for containerd
    pkgs.krb5 # kinit / klist / kdestroy for MATOS.CC realm
  ];

  # nerdctl — transparent sudo so rootful containerd works as non-root
  programs.fish.shellAliases = {
    nerdctl = "sudo nerdctl";
  };
}
