{ nix-secrets, ... }:

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
    ../../../modules/nixos/syncthing-password.nix
    ../../../modules/nixos/syncthing-healthcheck.nix
    ../../../modules/nixos/smtp-relay.nix
  ];

  networking.hostName = "huginn";

  # Firewall — SSH (22) is already opened by common-nixos.nix.
  # Restrict SSH, Syncthing GUI, and SMTP/SMTPS to the local subnet;
  # Syncthing sync protocol (22000) open globally for peer connectivity.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 ];
    extraInputRules = ''
      ip  saddr 10.0.4.0/22 tcp dport 8384 accept
      ip  saddr 10.0.4.0/22 tcp dport 25   accept
      ip  saddr 10.0.4.0/22 tcp dport 465  accept
    '';
  };

  nixie = {
    krb5.keytabFile = "${nix-secrets}/keytab-huginn.age";

    # SMTP relay — Postfix smarthost via Fastmail; primary relay for the fleet
    # (see ARCHITECTURE.md §10 Stage 5/6 — porkchop becomes the backup relay).
    # Accepts from localhost, LAN, and Tailscale (tailscale0 is trusted at the
    # firewall level in common-nixos.nix). SMTPS (port 465) uses the
    # certbot-managed cert from /etc/postfix/ssl/.
    smtpRelay = {
      enable = true;
      myNetworks = [
        "127.0.0.0/8"
        "[::1]/128"
        "10.0.4.0/22"
        "100.64.0.0/10" # Tailscale CGNAT — fleet hosts relay via huginn.ts.matos.cc
      ];
      smtps.enable = true;
    };

    # Certbot — certificates via LuaDNS DNS-01 challenge.
    # postfixDeploy copies renewed cert+key to /etc/postfix/ssl/ (root:postfix 640)
    # and reloads postfix so SMTPS picks up the new cert without dropping connections.
    certbot = {
      enable = true;
      domains = [
        [
          "huginn.home.matos.cc"
          "huginn.ts.matos.cc"
        ]
        [
          "mail.home.matos.cc"
          "mail.ts.matos.cc"
        ]
      ];
      syncthingDeploy = true;
      postfixDeploy = true;
    };
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
