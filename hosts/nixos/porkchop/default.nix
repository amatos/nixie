{
  nix-keytabs-matos-cc,
  ...
}:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
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
  # subnet on IPv4. Tailscale is already covered by trustedInterfaces =
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
