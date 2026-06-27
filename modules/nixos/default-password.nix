# Deploys the default NixOS user password secret and applies it to
# root, nixos, and alberth via hashedPasswordFile.
#
# The secret must contain a hashed password (e.g. the output of
# mkpasswd -m sha-512). It is decrypted to /run/agenix at activation
# time by ragenix, before the users activation script runs.
{ nix-secrets, ... }:

{
  age.secrets.default-nixos-user-password = {
    file = "${nix-secrets}/default-nixos-user-password.age";
    owner = "root";
    mode = "0400";
  };

  users.users.root.hashedPasswordFile = "/run/agenix/default-nixos-user-password";
  users.users.nixos.hashedPasswordFile = "/run/agenix/default-nixos-user-password";
  users.users.alberth.hashedPasswordFile = "/run/agenix/default-nixos-user-password";
}
