# Kerberos client configuration for MATOS.CC realm.
#
# Uses lib.mkDefault so that on muninn (the KDC host, since the Stage 3
# fleet-wide cutover in ARCHITECTURE.md §10 — previously porkchop) the full
# server-side krb5.conf written by the nix-kerberos-ldap kerberos module at
# normal priority silently wins without a conflict.
#
# Set nixie.krb5.keytabFile to the sops-encrypted binary keytab path in
# nix-secrets to have it deployed to /etc/krb5.keytab on activation.
{ config, lib, ... }:
{
  options.nixie.krb5.keytabFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = ''
      Path to the sops-encrypted binary host keytab in nix-secrets (e.g.
      "''${nix-secrets}/keytab-codex.age").  When set, the keytab is
      deployed to /etc/krb5.keytab on activation.  Leave null on hosts
      that do not yet have a keytab issued.
    '';
  };

  config = lib.mkMerge [
    {
      environment.etc."krb5.conf".text = lib.mkDefault ''
        [libdefaults]
          default_realm = MATOS.CC
          dns_lookup_realm = false
          dns_lookup_kdc = false
          dns_canonicalize_hostname = false
          rdns = false

        [realms]
          MATOS.CC = {
            kdc = muninn.ts.matos.cc
            admin_server = muninn.ts.matos.cc
          }

        [domain_realm]
          .matos.cc = MATOS.CC
          matos.cc = MATOS.CC
      '';
    }

    (lib.mkIf (config.nixie.krb5.keytabFile != null) {
      sops.secrets.hostKeytab = {
        sopsFile = config.nixie.krb5.keytabFile;
        format = "binary";
        path = "/etc/krb5.keytab";
        owner = "root";
        mode = "0600";
      };
    })
  ];
}
