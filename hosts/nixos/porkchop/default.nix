{ lib, ... }:

let
  userDefs = import ../../../users.nix;
  primaryUser = userDefs.primaryUser;
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
  # SMTP relay (port 25) restricted to local subnet on IPv4; Tailscale is
  # already covered by trustedInterfaces = ["tailscale0"] in common-nixos.nix.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 ];
    extraInputRules = ''
      ip  saddr 10.0.4.0/22 tcp dport 8384 accept
      ip6 nexthdr tcp tcp dport 8384 accept
      ip  saddr 10.0.4.0/22 tcp dport 25  accept
    '';
  };

  # SMTP relay — Postfix smarthost via Fastmail; accepts from localhost, LAN,
  # and Tailscale (tailscale0 is trusted at the firewall level in common-nixos.nix)
  nixie.smtpRelay = {
    enable = true;
    myNetworks = [
      "127.0.0.0/8"
      "[::1]/128"
      "10.0.4.0/22"
    ];
  };

  # Certbot — certificates via LuaDNS DNS-01 challenge
  nixie.certbot = {
    enable = true;
    domains = [
      [
        "porkchop.home.matos.cc"
        "porkchop.ts.matos.cc"
      ]
    ];
    syncthingDeploy = true;
  };
}
