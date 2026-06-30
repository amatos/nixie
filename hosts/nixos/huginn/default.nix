{ keytabs-matos-cc, ... }:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  imports = [
    ./hardware-configuration.nix
    ../common-nixos.nix
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
      ip6 nexthdr tcp tcp dport 8384 accept
    '';
  };

  # Host-specific home overlay — uncomment and create the file if needed.
  # The NixOS common overlay (home/alberth/nixos.nix) is already applied
  # via modules/nixos/home-manager.nix; only add this if extra settings
  # are required for this specific host.
  home-manager.users.${primaryUser} = {
    imports = [ ../../../home/alberth/huginn.nix ];
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
}
