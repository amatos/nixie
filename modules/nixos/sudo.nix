# Allow members of the wheel group to run nixos-rebuild without a password.
{ ... }:

{
  environment.etc."sudoers.d/nix-rebuild-sudoers" = {
    text = ''
      %wheel ALL=(ALL:ALL) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild
    '';
    mode = "0440";
  };
}
