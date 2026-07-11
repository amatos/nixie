# Deploys per-user password secrets and applies them via hashedPasswordFile.
#
# Each secret must contain a hashed password (e.g. the output of
# mkpasswd -m sha-512). Decrypted to /run/agenix at activation time by
# ragenix, before the users activation script runs.
#
# root shares the "nixos" account's password rather than getting its own
# secret — both exist purely for initial setup/emergency access, matching
# users.nix's description of the "nixos" account.
{ config, nix-secrets, ... }:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  age.secrets.user-password-alberth = {
    file = "${nix-secrets}/users/alberth.age";
    owner = "root";
    mode = "0400";
  };
  age.secrets.user-password-nixos = {
    file = "${nix-secrets}/users/nixos.age";
    owner = "root";
    mode = "0400";
  };

  users.users.${primaryUser}.hashedPasswordFile = config.age.secrets.user-password-alberth.path;
  users.users.nixos.hashedPasswordFile = config.age.secrets.user-password-nixos.path;
  users.users.root.hashedPasswordFile = config.age.secrets.user-password-nixos.path;
}
