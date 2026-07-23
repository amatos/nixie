{
  pkgs,
  nix-secrets,
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
    ../../../modules/nixos/syncthing-password.nix
    ../../../modules/nixos/syncthing-healthcheck.nix
  ];

  networking.hostName = "muninn";

  # Firewall — SSH (22) is already opened by common-nixos.nix.
  # Restrict SSH, Syncthing GUI, and LDAP/Kerberos to the local subnet;
  # Syncthing sync protocol (22000) open globally for peer connectivity.
  # LDAP (389) and LDAPS (636) are LAN-reachable here (unlike porkchop's
  # current Tailscale-only exposure) — a deliberate choice for this
  # migration, see ARCHITECTURE.md §10 Stage 2. Tailscale is already
  # covered by trustedInterfaces = ["tailscale0"] in common-nixos.nix.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 ];
    extraInputRules = ''
      ip  saddr 10.0.4.0/22 tcp dport 8384 accept
      ip  saddr 10.0.4.0/22 tcp dport 389  accept
      ip  saddr 10.0.4.0/22 tcp dport 636  accept
      ip  saddr 10.0.4.0/22 tcp dport 88   accept
      ip  saddr 10.0.4.0/22 udp dport 88   accept
      ip  saddr 10.0.4.0/22 tcp dport 464  accept
      ip  saddr 10.0.4.0/22 udp dport 464  accept
      ip  saddr 10.0.4.0/22 tcp dport 749  accept
    '';
  };

  # Kerberos + LDAP — KDC backed by OpenLDAP. Stood up alongside porkchop's
  # existing KDC/LDAP during the migration window (ARCHITECTURE.md §10
  # Stage 2); porkchop remains authoritative until Stage 3 cuts the fleet
  # realm pointer over and Stage 4 decommissions it there.
  # Bootstrap after first deploy (mirrors porkchop's original bootstrap):
  #   1. kdb5_ldap_util stashsrvpw -f /var/lib/krb5kdc/service.keyfile cn=kdc,dc=matos,dc=cc
  #   2. kdb5_util create -s -r MATOS.CC
  #   3. kadmin.local addprinc <user>
  # (or, when migrating porkchop's existing data: slapadd + kdb5_util load
  # instead of steps 2-3 — see ARCHITECTURE.md §10 Stage 2.)
  services.kerberosLdap = {
    ldap = {
      enable = true;
      domain = "matos.cc";
      baseDN = "dc=matos,dc=cc";
      # SASL/GSSAPI — slapd authenticates clients via Kerberos tickets.
      # saslKeytabFile: sops-encrypted (binary) keytab for the ldap/ service
      #   principal; deployed to /run/secrets/ldapSaslKeytab with openldap
      #   ownership. Contains TWO principals: ldap/muninn.ts.matos.cc (the "intended"
      #   custom-domain name, unreachable in practice — see below) and
      #   ldap/muninn.tail2269e5.ts.net (the tailnet's real native MagicDNS
      #   name, what clients actually request tickets for).
      # saslHost: deliberately left unset. Cyrus SASL's GSSAPI client plugin
      #   builds its target service principal from the peer's *reverse-DNS*
      #   name, not the hostname/URL used to connect — and Tailscale's own
      #   PTR records always answer with the tailnet's native
      #   "<host>.tail<id>.ts.net" name, never a custom alias like
      #   "ts.matos.cc", regardless of ldap.conf's SASL_NOCANON or krb5.conf's
      #   rdns/dns_canonicalize_hostname settings (neither reaches this
      #   codepath). Setting olcSaslHost to "muninn.ts.matos.cc" made slapd
      #   reject every real GSSAPI bind outright (gss_accept_sec_context
      #   failure) since it only ever tried the one keytab entry matching
      #   that hostname. Leaving saslHost unset lets slapd accept any
      #   principal present in the keytab instead — see ARCHITECTURE.md §10
      #   Stage 2 for the full debugging trail; this was a real, pre-existing
      #   bug in the realm's GSSAPI setup, reproduced identically on
      #   porkchop, not something introduced by this migration.
      # saslAuthzRegexp: maps <primaryUser>@MATOS.CC to the LDAP rootDN so
      #   ldapwhoami/ldapsearch/ldapmodify work with a valid TGT. The pattern
      #   below (3 DN components: uid=.../cn=gssapi/cn=auth) matches what
      #   this cyrus-sasl/krb5 version actually produces — no separate
      #   "cn=<realm>" component appears, despite the extra "cn=[^,]*,"
      #   segment doc'd elsewhere (and previously here) assuming one does.
      saslKeytabFile = "${nix-secrets}/keytab-ldap-muninn.age";
      saslAuthzRegexp = [
        "{0}uid=${primaryUser},cn=gssapi,cn=auth cn=admin,dc=matos,dc=cc"
      ];
      # Listen on all interfaces so remote hosts and GSSAPI clients can
      # reach slapd via the FQDN. The firewall restricts LDAP (389) to
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

  nixie.krb5.keytabFile = "${nix-secrets}/keytab-muninn.age";

  # Certbot — certificates via LuaDNS DNS-01 challenge.
  # ldapDeploy copies renewed cert+key to /var/lib/openldap-tls/ (root:openldap 640)
  # and reloads slapd so LDAPS picks up the new cert without dropping connections.
  nixie.certbot = {
    enable = true;
    domains = [
      [
        "muninn.home.matos.cc"
        "muninn.ts.matos.cc"
      ]
    ];
    syncthingDeploy = true;
    ldapDeploy = true;
  };

  # Syncthing — runs as a systemd service, syncs to the primary user's home.
  # GUI password is managed via syncthing-password.nix (ragenix secret).
  #
  # guiAddress/settings.gui.address use the IPv4 wildcard "0.0.0.0", not the
  # IPv6 wildcard "[::]" — see CLAUDE.md Syncthing conventions for why (the
  # short version: NixOS's syncthing-init service breaks against "::").
  services.syncthing = {
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
}
