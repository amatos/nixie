# devenv — per-project developer environment manager.
# https://devenv.sh
#
# Per-project configuration lives in each project's devenv.nix (shell,
# packages, services, processes) and devenv.yaml (flake inputs). This file
# handles global installation and machine-wide settings only.
{ pkgs, ... }:

{
  home.packages = [ pkgs.devenv ];

  cachix.pull = [ "amatos" ];

  # Global devenv configuration written to ~/.config/devenv/devenv.yaml.
  # See https://devenv.sh/reference/yaml-options/ for available options.
  xdg.configFile."devenv/devenv.yaml".text = ''
    # Override the default nixpkgs input for new projects:
    # inputs:
    #   nixpkgs:
    #     url: github:NixOS/nixpkgs/nixpkgs-unstable
  '';
}
