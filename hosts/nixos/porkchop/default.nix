{
  lib,
  pkgs,
  nix-secrets,
  ...
}:

let
  userDefs = import ../../../users.nix;
  primaryUser = userDefs.primaryUser;

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
    ../../../modules/nixos/syncthing-password.nix
    ../../../modules/nixos/smtp-relay.nix
  ];

  networking.hostName = "porkchop";

  # Syncthing — runs as a systemd service, syncs to the primary user's home.
  # GUI password is managed via syncthing-password.nix (ragenix secret).
  services.syncthing = {
    settings.gui.user = "syncthing";
    enable = true;
    user = primaryUser;
    dataDir = "/home/${primaryUser}";
    guiAddress = "[::]:8384";
    overrideDevices = false;
    overrideFolders = false;
    settings.gui.address = "[::]:8384";
    settings.options.listenAddresses = [
      "tcp://0.0.0.0:22000"
      "quic://0.0.0.0:22000"
    ];
  };

  # Firewall — Syncthing GUI restricted to local subnet on IPv4, open on IPv6;
  # Syncthing sync protocol (22000) open globally for peer connectivity.
  # SMTP (25) and SMTPS (465) restricted to local subnet on IPv4.
  # NTP (123 UDP) and NTS-KE (4460 TCP) restricted to local subnet on IPv4.
  # SMB (445/139 TCP, 137/138 UDP) and wsdd (3702 UDP) LAN-only.
  # Tailscale is already covered by trustedInterfaces = ["tailscale0"]
  # in common-nixos.nix.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 ];
    extraInputRules = ''
      ip  saddr 10.0.4.0/22 tcp dport 8384 accept
      ip6 nexthdr tcp tcp dport 8384 accept
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

  # SMTP relay — Postfix smarthost via Fastmail; accepts from localhost, LAN,
  # and Tailscale (tailscale0 is trusted at the firewall level in common-nixos.nix).
  # SMTPS (port 465) uses the certbot-managed cert from /etc/postfix/ssl/.
  nixie.smtpRelay = {
    enable = true;
    myNetworks = [
      "127.0.0.0/8"
      "[::1]/128"
      "10.0.4.0/22"
    ];
    smtps.enable = true;
  };

  # NTP/NTS server — chrony serves NTP (UDP 123) and NTS (TCP 4460) to LAN and
  # Tailscale clients. Upstream syncs to Cloudflare and Google via NTS for
  # authenticated time. NTS server cert is deployed by certbot's chronyDeploy hook
  # into /var/lib/chrony-tls/ (root:chrony 640).
  # chrony's allow directive is application-level access control independent of
  # the firewall; both LAN (10.0.4.0/22) and Tailscale CGNAT (100.64.0.0/10) are
  # permitted so Tailscale clients can reach the server over the VPN tunnel.
  services.chrony = {
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
  # After first deploy, set Samba passwords with:
  #   sudo smbpasswd -a alberth
  services.samba = {
    enable = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "porkchop";
        security = "user";
        "map to guest" = "never";
        "hosts allow" = "10.0.4.0/22 100.64.0.0/10 127.0.0.1";
        "hosts deny" = "0.0.0.0/0";
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
  services.samba-wsdd.enable = true;

  # Kerberos + LDAP — KDC backed by OpenLDAP.
  # OpenLDAP listens on 127.0.0.1 only; Kerberos ports (88, 464, 749) are
  # restricted to LAN on IPv4. Tailscale is covered by trustedInterfaces.
  # Bootstrap after first deploy:
  #   1. kdb5_ldap_util stashsrvpw -f /var/lib/krb5kdc/service.keyfile cn=kdc,dc=matos,dc=cc
  #   2. kdb5_util create -s -r MATOS.CC
  #   3. kadmin.local addprinc <user>
  services.kerberosLdap.ldap = {
    enable = true;
    domain = "matos.cc";
    baseDN = "dc=matos,dc=cc";
  };

  services.kerberosLdap.kerberos = {
    enable = true;
    realm = "MATOS.CC";
    krb5Package = krb5WithLdap;
  };

  nixie.krb5.keytabFile = "${nix-secrets}/keytab-porkchop.age";

  # Certbot — certificates via LuaDNS DNS-01 challenge.
  # postfixDeploy copies renewed cert+key to /etc/postfix/ssl/ (root:postfix 640)
  # and reloads postfix so SMTPS picks up the new cert without dropping connections.
  # chronyDeploy copies renewed cert+key to /var/lib/chrony-tls/ (root:chrony 640)
  # and restarts chronyd so the NTS server picks up the new cert.
  nixie.certbot = {
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
  };
}
