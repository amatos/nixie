# Allow members of the staff group to run darwin-rebuild without a password.
{ ... }:

{
  environment.etc."sudoers.d/nix-rebuild-sudoers" = {
    text = ''
      %staff ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild
    '';
    mode = "0440";
  };
}
