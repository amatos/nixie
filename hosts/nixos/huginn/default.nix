{ keytabs-matos-cc, ... }:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  imports = [
    ./hardware-configuration.nix
    ../common-nixos.nix
    ../../../modules/common/certbot-secrets.nix
    ../../../modules/nixos/syncthing-password.nix
  ];

  networking.hostName = "huginn";

  # Firewall — SSH (22) is already opened by common-nixos.nix.
  # Restrict SSH and Syncthing GUI to the local subnet;
  # Syncthing sync protocol (22000) open globally for peer connectivity
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 ];
    extraInputRules = ''
      ip  saddr 10.0.4.0/22 tcp dport 8384 accept
    '';
  };

  nixie.krb5.keytabFile = "${keytabs-matos-cc}/keytab-huginn.age";

  # Certbot — certificates via LuaDNS DNS-01 challenge
  nixie.certbot = {
    enable = true;
    domains = [
      [
        "huginn.home.matos.cc"
        "huginn.ts.matos.cc"
      ]
    ];
    syncthingDeploy = true;
  };

  # Syncthing — runs as a systemd service, syncs to the primary user's home.
  # GUI password is managed via syncthing-password.nix (ragenix secret).
  #
  # guiAddress/settings.gui.address use the IPv4 wildcard "0.0.0.0", not the
  # IPv6 wildcard "[::]" — see CLAUDE.md Syncthing conventions for why (the
  # short version: NixOS's syncthing-init service breaks against "::").
  services.syncthing = {
    settings.gui.user = "syncthing";
    enable = true;
    user = primaryUser;
    dataDir = "/home/${primaryUser}";
    guiAddress = "0.0.0.0:8384";
    overrideDevices = false;
    overrideFolders = false;
    settings.gui.address = "0.0.0.0:8384";
    settings.options.listenAddresses = [
      "tcp://0.0.0.0:22000"
      "quic://0.0.0.0:22000"
    ];
  };
}
