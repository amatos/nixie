# Sudo configuration for NixOS hosts.
# - Sources /etc/sudoers.d/* so drop-in files placed via environment.etc are honoured.
# - Allows wheel members to run nixos-rebuild without a password.
{ ... }:

{
  security.sudo.extraConfig = ''
    @includedir /etc/sudoers.d
  '';

  environment.etc."sudoers.d/nix-rebuild-sudoers" = {
    text = ''
      %wheel ALL=(ALL:ALL) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild
    '';
    mode = "0440";
  };
}
