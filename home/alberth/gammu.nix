# Gammu-specific home-manager settings for alberth.
{ pkgs, ... }:

{
  # Gammu-only packages
  home.packages = [
    pkgs.act # Run GitHub Actions locally
  ];
}
