{
  pkgs,
  nix-keytabs-matos-cc,
  ...
}:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;

  # Build krb5 with LDAP backend support in a clean nixpkgs instantiation,
  # completely separate from the system pkgs set.  Overlaying krb5 system-wide
  # causes an unavoidable cycle: krb5(LDAP) → openldap → cyrus-sasl → libkrb5
  # → (overlay) krb5(LDAP) …  Using pkgs.path gives us the same nixpkgs
  # source without any overlays, breaking the cycle.
  krb5WithLdap =
    (import pkgs.path {
      system = pkgs.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    }).krb5.override
      { withLdap = true; };
in
{
  imports = [
    ./hardware-configuration.nix
    ../common-nixos.nix
    ../../../modules/common/certbot-secrets.nix
    ../../../modules/common/smtp-relay-secrets.nix
    ../../../modules/common/dyndns-luadns-secrets.nix
    ../../../modules/common/unifi-backup-secrets.nix
    ../../../modules/nixos/syncthing-password.nix
    ../../../modules/nixos/syncthing-healthcheck.nix
    ../../../modules/nixos/smtp-relay.nix
    ../../../modules/nixos/dyndns-luadns.nix
    ../../../modules/nixos/unifi-backup.nix
  ];

  networking.hostName = "porkchop";

  # Firewall — Syncthing GUI restricted to local subnet on IPv4 (IPv4-only,
  # see syncthing block below); Syncthing sync protocol (22000) open globally
  # for peer connectivity. SMTP (25) and SMTPS (465) restricted to local
  # subnet on IPv4. NTP (123 UDP) and NTS-KE (4460 TCP) restricted to local
  # subnet on IPv4. SMB (445/139 TCP, 137/138 UDP) and wsdd (3702 UDP)
  # LAN-only. Tailscale is already covered by trustedInterfaces =
  # ["tailscale0"] in common-nixos.nix.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 ];
    extraInputRules = ''
      ip  saddr 10.0.4.0/22 tcp dport 8384 accept
      ip  saddr 10.0.4.0/22 tcp dport 25   accept
      ip  saddr 10.0.4.0/22 tcp dport 465  accept
      ip  saddr 10.0.4.0/22 udp dport 123  accept
      ip  saddr 10.0.4.0/22 tcp dport 4460 accept
      ip  saddr 10.0.4.0/22 tcp dport 445  accept
      ip  saddr 10.0.4.0/22 tcp dport 139  accept
      ip  saddr 10.0.4.0/22 udp dport 137  accept
      ip  saddr 10.0.4.0/22 udp dport 138  accept
      ip  saddr 10.0.4.0/22 udp dport 3702 accept
      ip  saddr 10.0.4.0/22 tcp dport 88   accept
      ip  saddr 10.0.4.0/22 udp dport 88   accept
      ip  saddr 10.0.4.0/22 tcp dport 464  accept
      ip  saddr 10.0.4.0/22 udp dport 464  accept
      ip  saddr 10.0.4.0/22 tcp dport 749  accept
    '';
  };

  services = {
    # Syncthing — runs as a systemd service, syncs to the primary user's home.
    # GUI password is managed via syncthing-password.nix (ragenix secret).
    #
    # guiAddress/settings.gui.address use the IPv4 wildcard "0.0.0.0", not the
    # IPv6 wildcard "[::]" — see CLAUDE.md Syncthing conventions for why (the
    # short version: NixOS's syncthing-init service breaks against "::").
    syncthing = {
      enable = true;
      user = primaryUser;
      dataDir = "/home/${primaryUser}";
      guiAddress = "0.0.0.0:8384";
      overrideDevices = false;
      overrideFolders = false;
      settings = {
        gui = {
          user = "syncthing";
          address = "0.0.0.0:8384";
        };
        options.listenAddresses = [
          "tcp://0.0.0.0:22000"
          "quic://0.0.0.0:22000"
        ];
      };
    };

    # NTP/NTS server — chrony serves NTP (UDP 123) and NTS (TCP 4460) to LAN and
    # Tailscale clients. Upstream syncs to Cloudflare and Google via NTS for
    # authenticated time. NTS server cert is deployed by certbot's chronyDeploy hook
    # into /var/lib/chrony-tls/ (root:chrony 640).
    # chrony's allow directive is application-level access control independent of
    # the firewall; both LAN (10.0.4.0/22) and Tailscale CGNAT (100.64.0.0/10) are
    # permitted so Tailscale clients can reach the server over the VPN tunnel.
    chrony = {
      enable = true;
      servers = [ ];
      extraConfig = ''
        # Upstream time sources — NTS-authenticated for cryptographic integrity.
        server time.cloudflare.com iburst nts
        server time1.google.com    iburst nts
        server time2.google.com    iburst nts
        server time3.google.com    iburst nts

        # NTS server — certificate deployed by certbot's chronyDeploy hook.
        ntsservercert /var/lib/chrony-tls/fullchain.pem
        ntsserverkey  /var/lib/chrony-tls/privkey.pem
        ntsdumpdir /var/lib/chrony

        # Allow NTP/NTS clients on LAN and Tailscale CGNAT range.
        allow 10.0.4.0/22
        allow 100.64.0.0/10
      '';
    };

    # Samba — expose each user's home directory to that user only.
    # Restricted to LAN (10.0.4.0/22) and Tailscale (trusted via tailscale0).
    # Kerberos auth uses the host keytab (/etc/krb5.keytab); clients with a
    # valid TGT get transparent access. The keytab must contain both
    # host/porkchop.matos.cc and cifs/porkchop.matos.cc principals.
    # After first deploy, set Samba passwords with:
    #   sudo smbpasswd -a alberth
    samba = {
      enable = true;
      settings = {
        global = {
          workgroup = "WORKGROUP";
          "server string" = "porkchop";
          security = "user";
          "map to guest" = "never";
          "hosts allow" = "10.0.4.0/22 100.64.0.0/10 127.0.0.1";
          "hosts deny" = "0.0.0.0/0";
          # Kerberos — clients authenticate with a TGT; Samba verifies via keytab.
          realm = "MATOS.CC";
          "kerberos method" = "dedicated keytab";
          "dedicated keytab file" = "/etc/krb5.keytab";
        };
        "${primaryUser}" = {
          path = "/home/${primaryUser}";
          "valid users" = primaryUser;
          "read only" = "no";
          "guest ok" = "no";
          browseable = "yes";
        };
      };
    };

    # wsdd — makes porkchop discoverable in Windows/macOS network browsers
    samba-wsdd.enable = true;

    # Kerberos + LDAP — KDC backed by OpenLDAP.
    # OpenLDAP listens on 127.0.0.1 only; Kerberos ports (88, 464, 749) are
    # restricted to LAN on IPv4. Tailscale is covered by trustedInterfaces.
    # Bootstrap after first deploy:
    #   1. kdb5_ldap_util stashsrvpw -f /var/lib/krb5kdc/service.keyfile cn=kdc,dc=matos,dc=cc
    #   2. kdb5_util create -s -r MATOS.CC
    #   3. kadmin.local addprinc <user>
    kerberosLdap = {
      ldap = {
        enable = true;
        domain = "matos.cc";
        baseDN = "dc=matos,dc=cc";
        # SASL/GSSAPI — slapd authenticates clients via Kerberos tickets.
        # saslKeytabFile: age-encrypted keytab for the ldap/ service principal;
        #   deployed to /run/agenix/ldapSaslKeytab with openldap ownership.
        # saslHost: must match the hostname component of the ldap/ principal.
        # saslAuthzRegexp: maps <primaryUser>@MATOS.CC to the LDAP rootDN so
        #   ldapwhoami/ldapsearch/ldapmodify work with a valid TGT.
        saslKeytabFile = "${nix-keytabs-matos-cc}/keytab-ldap-porkchop.age";
        saslHost = "porkchop.ts.matos.cc";
        saslAuthzRegexp = [
          "{0}uid=${primaryUser},cn=[^,]*,cn=gssapi,cn=auth cn=admin,dc=matos,dc=cc"
        ];
        # Listen on all interfaces so remote hosts and GSSAPI clients can
        # reach slapd via the FQDN.  The firewall restricts LDAP (389) to
        # LAN (10.0.4.0/22); Tailscale is covered by trustedInterfaces.
        # ldaps:/// enables LDAPS on port 636; cert+key deployed by certbot.
        listenAddresses = [
          "ldap://0.0.0.0:389/"
          "ldaps:///"
        ];
        # TLS — cert+key deployed by certbot's ldapDeploy hook into
        # /var/lib/openldap-tls/ with root:openldap 640 ownership.
        tlsCertFile = "/var/lib/openldap-tls/fullchain.pem";
        tlsKeyFile = "/var/lib/openldap-tls/privkey.pem";
      };

      kerberos = {
        enable = true;
        realm = "MATOS.CC";
        krb5Package = krb5WithLdap;
      };
    };
  };

  nixie = {
    # SMTP relay — Postfix smarthost via Fastmail; accepts from localhost, LAN,
    # and Tailscale (tailscale0 is trusted at the firewall level in common-nixos.nix).
    # SMTPS (port 465) uses the certbot-managed cert from /etc/postfix/ssl/.
    smtpRelay = {
      enable = true;
      myNetworks = [
        "127.0.0.0/8"
        "[::1]/128"
        "10.0.4.0/22"
        "100.64.0.0/10" # Tailscale CGNAT — fleet hosts relay via porkchop.ts.matos.cc
      ];
      smtps.enable = true;
    };

    krb5.keytabFile = "${nix-keytabs-matos-cc}/keytab-porkchop.age";

    # Certbot — certificates via LuaDNS DNS-01 challenge.
    # postfixDeploy copies renewed cert+key to /etc/postfix/ssl/ (root:postfix 640)
    # and reloads postfix so SMTPS picks up the new cert without dropping connections.
    # chronyDeploy copies renewed cert+key to /var/lib/chrony-tls/ (root:chrony 640)
    # and restarts chronyd so the NTS server picks up the new cert.
    certbot = {
      enable = true;
      domains = [
        [
          "porkchop.home.matos.cc"
          "porkchop.ts.matos.cc"
          "mail.home.matos.cc"
          "mail.ts.matos.cc"
        ]
      ];
      syncthingDeploy = true;
      postfixDeploy = true;
      chronyDeploy = true;
      ldapDeploy = true;
    };

    # Dynamic DNS — keeps home.matos.cc pointed at the current WAN IP by
    # polling the UDM's local API and updating LuaDNS's dyndns2 endpoint
    # (over HTTPS) when it changes. See modules/nixos/dyndns-luadns.nix.
    dyndnsLuadns = {
      enable = true;
      hostname = "home.matos.cc";
      gatewayHost = "unifi";
      interval = "5min";
    };

    # UniFi backup — daily scp of the UniFi Network autobackup directory from
    # unifi.home.matos.cc into the primary user's home. Uses the SSH key
    # deployed by modules/common/unifi-backup-secrets.nix (nix-secrets); the
    # matching public key must be added to unifi.home.matos.cc's root
    # authorized_keys. See modules/nixos/unifi-backup.nix.
    unifiBackup = {
      enable = true;
      localDir = "/home/${primaryUser}/backups/unifi";
    };
  };
}
