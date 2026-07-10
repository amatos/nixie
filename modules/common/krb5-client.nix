# Kerberos client configuration for MATOS.CC realm.
#
# Uses lib.mkDefault so that on porkchop (the KDC host) the full
# server-side krb5.conf written by the nix-kerberos-ldap kerberos
# module at normal priority silently wins without a conflict.
#
# Set nixie.krb5.keytabFile to the age-encrypted keytab path in
# nix-keytabs-matos-cc to have it deployed to /etc/krb5.keytab on activation.
{ config, lib, ... }:
{
  options.nixie.krb5.keytabFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = ''
      Path to the age-encrypted host keytab in nix-keytabs-matos-cc (e.g.
      "''${nix-keytabs-matos-cc}/keytab-codex.age").  When set, the keytab is
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
            kdc = porkchop.ts.matos.cc
            admin_server = porkchop.ts.matos.cc
          }

        [domain_realm]
          .matos.cc = MATOS.CC
          matos.cc = MATOS.CC
      '';
    }

    (lib.mkIf (config.nixie.krb5.keytabFile != null) {
      age.secrets.hostKeytab = {
        file = config.nixie.krb5.keytabFile;
        path = "/etc/krb5.keytab";
        owner = "root";
        mode = "0600";
      };
    })
  ];
}
