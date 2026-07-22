# Deploys per-user password secrets and applies them via hashedPasswordFile.
#
# Each secret must contain a hashed password (e.g. the output of
# mkpasswd -m sha-512). neededForUsers = true ensures sops-nix decrypts these
# before the users activation script runs (same ordering guarantee ragenix
# gave for free, since agenix always ran before users activation).
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
  sops.secrets.user-password-alberth = {
    sopsFile = "${nix-secrets}/fleet-secrets.yaml";
    key = "user-password-alberth";
    owner = "root";
    mode = "0400";
    neededForUsers = true;
  };
  sops.secrets.user-password-nixos = {
    sopsFile = "${nix-secrets}/fleet-secrets.yaml";
    key = "user-password-nixos";
    owner = "root";
    mode = "0400";
    neededForUsers = true;
  };

  users.users = {
    ${primaryUser}.hashedPasswordFile = config.sops.secrets.user-password-alberth.path;
    nixos.hashedPasswordFile = config.sops.secrets.user-password-nixos.path;
    root.hashedPasswordFile = config.sops.secrets.user-password-nixos.path;
  };
}
