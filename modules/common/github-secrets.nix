# Deploys GitHub SSH keys from nix-secrets into the primary user's ~/.ssh directory.
# Path differs by platform: /Users/<user> on darwin, /home/<user> on NixOS.
{
  pkgs,
  nix-secrets,
  ...
}:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
  home = if pkgs.stdenv.isDarwin then "/Users/${primaryUser}" else "/home/${primaryUser}";
in
{
  age.secrets.github-ratelimit = {
    file = "${nix-secrets}/github-ratelimit.age";
    path = "${home}/.ssh/github-ratelimit";
    owner = primaryUser;
    mode = "0600";
  };

  age.secrets.github-ssh-key = {
    file = "${nix-secrets}/github-ssh-key.age";
    path = "${home}/.ssh/github-ssh-key";
    owner = primaryUser;
    mode = "0600";
  };
}
