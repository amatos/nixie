# Deploys GitHub SSH keys from nix-secrets into the primary user's ~/.ssh directory.
# Path differs by platform: /Users/<user> on darwin, /home/<user> on NixOS.
{
  pkgs,
  lib,
  nix-secrets,
  ...
}:

let
  userDefs = import ../../users.nix;
  primaryUser = userDefs.primaryUser;
  home = if pkgs.stdenv.isDarwin then "/Users/${primaryUser}" else "/home/${primaryUser}";
in
{
  # Ensure ~/.ssh is owned by the primary user before agenix places secrets
  # there. Without this, agenix (running as root) creates the directory as
  # root, which then blocks home-manager from writing ~/.ssh/config.
  # tmpfiles runs before agenix on NixOS; darwin is unaffected.
  systemd.tmpfiles.rules = lib.optionals pkgs.stdenv.isLinux [
    "d ${home}/.ssh 0700 ${primaryUser} users - -"
  ];
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
