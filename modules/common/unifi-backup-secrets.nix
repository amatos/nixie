# Deploys the SSH private key used by modules/nixos/unifi-backup.nix to scp
# UniFi OS's autobackup directory from unifi.home.matos.cc.
#
# The corresponding public key must be added to unifi.home.matos.cc's
# authorized_keys for the SSH user configured via nixie.unifiBackup.remoteUser
# (see modules/nixos/unifi-backup.nix) — ragenix only manages the private half.
#
# Decrypted to tmpfs at /run/agenix/unifi-backup-ssh-key — never written to
# disk. Owned by the primary user (not root) so unifi-backup.service, which
# runs as that user to write into their home directory, can read it.
#
# After adding unifi-backup-ssh-key.age to nix-secrets, run:
#   ragenix --rekey
# to encrypt it for all configured recipients (host keys + YubiKey).
{ nix-secrets, ... }:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  age.secrets.unifi-backup-ssh-key = {
    file = "${nix-secrets}/unifi/backup-ssh-key.age";
    owner = primaryUser;
    mode = "0400";
    # path intentionally omitted — defaults to /run/agenix/unifi-backup-ssh-key
  };
}
