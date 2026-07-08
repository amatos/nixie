# Backs up UniFi OS's autobackup directory from a UniFi gateway (unifi.home.matos.cc)
# to a local directory on this host, via scp over SSH key auth.
#
# The script is deployed as `unifi_backup.sh` (added to environment.systemPackages,
# so it can also be run manually) and wrapped in a systemd oneshot service + timer
# for the automatic run. It uses the primary user's SSH private key deployed by
# modules/common/unifi-backup-secrets.nix (nix-secrets) — the matching public key
# must already be added to the remote host's authorized_keys for
# nixie.unifiBackup.remoteUser.
#
# remotePath defaults to a directory (UniFi Network's autobackup location), copied
# recursively with scp -r; the last path component ("autobackup") lands as a
# subdirectory under localDir, e.g. <localDir>/autobackup/*.unf.
#
# Host key trust is TOFU (StrictHostKeyChecking=accept-new) against a dedicated
# known_hosts file under stateDir, kept separate from the primary user's own
# interactive ~/.ssh/known_hosts.
#
# IdentitiesOnly=yes + PreferredAuthentications=publickey: the primary user's
# home-manager-managed ~/.ssh/config (nixie-homes' alberth/common/ssh.nix) has a
# `Host *` block with its own `IdentityFile ~/.ssh/id_rsa` and
# `GSSAPIAuthentication yes` — ssh_config's IdentityFile keyword is cumulative
# across matching Host blocks, so without IdentitiesOnly=yes ssh also offers
# that (nonexistent, on porkchop) identity and attempts GSSAPI first, adding
# noisy/misleading "no such identity" errors to the log before ever getting
# to the key that actually matters. These two options make the service use
# *only* the ragenix-deployed key.
#
# Usage — in a host's default.nix:
#   nixie.unifiBackup = {
#     enable = true;
#     localDir = "/home/alberth/backups/unifi";
#   };
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.nixie.unifiBackup;
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
  stateDir = "/var/lib/unifi-backup";

  backupScript = pkgs.writeShellScriptBin "unifi_backup.sh" ''
    set -euo pipefail

    mkdir -p "${cfg.localDir}"

    ${pkgs.openssh}/bin/scp -r \
      -o BatchMode=yes \
      -o IdentitiesOnly=yes \
      -o PreferredAuthentications=publickey \
      -o StrictHostKeyChecking=accept-new \
      -o UserKnownHostsFile=${stateDir}/known_hosts \
      -i /run/agenix/unifi-backup-ssh-key \
      "${cfg.remoteUser}@${cfg.remoteHost}:${cfg.remotePath}" \
      "${cfg.localDir}"
  '';
in
{
  options.nixie.unifiBackup = {
    enable = lib.mkEnableOption "scheduled scp backup of a UniFi gateway's autobackup directory";

    remoteHost = lib.mkOption {
      type = lib.types.str;
      default = "unifi.home.matos.cc";
      description = "UniFi OS console to scp the autobackup directory from.";
    };

    remoteUser = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "SSH user on the UniFi OS console. Must match the account the deployed public key was added to.";
    };

    remotePath = lib.mkOption {
      type = lib.types.str;
      default = "/data/unifi/data/backup/autobackup/";
      description = "Remote directory to copy (scp -r) — UniFi Network's default autobackup location on UniFi OS consoles.";
    };

    localDir = lib.mkOption {
      type = lib.types.str;
      example = "/home/alberth/backups/unifi";
      description = "Local directory to copy backups into. Created automatically (owned by the primary user) if missing.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "How often to run the backup. See {command}`man 7 systemd.time` (OnCalendar format).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ backupScript ];

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 ${primaryUser} ${primaryUser} -"
    ];

    systemd.services.unifi-backup = {
      description = "scp backup of UniFi autobackup directory from ${cfg.remoteHost}";
      after = [
        "network-online.target"
        "agenix.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = primaryUser;
        ExecStart = "${backupScript}/bin/unifi_backup.sh";
      };
    };

    systemd.timers.unifi-backup = {
      description = "UniFi backup timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        RandomizedDelaySec = "30min";
        Persistent = true;
      };
    };
  };
}
