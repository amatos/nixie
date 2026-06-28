{ lib, pkgs, ... }:

let
  userDefs = import ../../../users.nix;
  primaryUser = userDefs.primaryUser;
in
{
  imports = [
    ./hardware-configuration.nix
    ../common-nixos.nix
    ../../../modules/common/certbot-secrets.nix
    ../../../modules/nixos/syncthing-password.nix
  ];

  networking.hostName = "gammu";

  # containerd — container runtime; starts automatically via systemd
  virtualisation.containerd.enable = true;

  # Allow the primary user to reach the containerd socket without sudo
  users.groups.containerd = { };
  users.users.${primaryUser}.extraGroups = [ "containerd" ];
  systemd.services.containerd.serviceConfig.ExecStartPost = [
    "+${pkgs.coreutils}/bin/chgrp containerd /run/containerd/containerd.sock"
    "+${pkgs.coreutils}/bin/chmod 660 /run/containerd/containerd.sock"
  ];

  # Merge gammu home overlay on top of the base imported by common-nixos.nix
  home-manager.users.${primaryUser} = {
    imports = [ ../../../home/alberth/gammu.nix ];
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

  # Firewall — restrict SSH and Syncthing GUI to the local subnet;
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

  # Certbot — certificates via LuaDNS DNS-01 challenge
  nixie.certbot = {
    enable = true;
    domains = [
      [
        "gammu.home.matos.cc"
        "gammu.ts.matos.cc"
      ]
    ];
    syncthingDeploy = true;
  };
}
