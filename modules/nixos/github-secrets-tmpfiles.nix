# Ensure ~/.ssh is owned by the primary user before agenix places secrets
# there. Without this, agenix (running as root) creates the directory as
# root, which then blocks home-manager from writing ~/.ssh/config.
# tmpfiles runs before agenix on NixOS; darwin has no systemd, so this is
# kept out of modules/common/github-secrets.nix and only imported here.
{ ... }:

let
  userDefs = import ../../users.nix;
  primaryUser = userDefs.primaryUser;
  home = "/home/${primaryUser}";
in
{
  systemd.tmpfiles.rules = [
    "d ${home}/.ssh 0700 ${primaryUser} users - -"
  ];
}
