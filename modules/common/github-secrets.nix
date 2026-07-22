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
  sops.secrets.github-ratelimit = {
    sopsFile = "${nix-secrets}/fleet-secrets.yaml";
    key = "github-ratelimit";
    path = "${home}/.ssh/github-ratelimit";
    owner = primaryUser;
    mode = "0600";
  };

  sops.secrets.github-ssh-key = {
    sopsFile = "${nix-secrets}/fleet-secrets.yaml";
    key = "github-ssh-key";
    path = "${home}/.ssh/github-ssh-key";
    owner = primaryUser;
    mode = "0600";
  };
}
