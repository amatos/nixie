# Install Ghostty only when a graphical environment is configured.
# Covers X11 (services.xserver.enable) and display-manager-only Wayland setups.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  environment.systemPackages = lib.optionals (
    config.services.xserver.enable || config.services.displayManager.enable
  ) [ pkgs.ghostty ];
}
