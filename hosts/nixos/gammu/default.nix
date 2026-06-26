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
  ];

  networking.hostName = "gammu";

  # Syncthing — runs as a systemd service, syncs to the primary user's home
  services.syncthing = {
    enable = true;
    user = primaryUser;
    dataDir = "/home/${primaryUser}";
    guiAddress = "0.0.0.0:8384";
  };

  # Firewall — restrict SSH and Syncthing GUI to the local subnet
  networking.firewall = {
    enable = true;
    # Override the global SSH rule from common-nixos.nix; access is subnet-restricted below
    allowedTCPPorts = lib.mkForce [ ];
    extraInputRules = ''
      ip saddr 10.0.4.0/22 tcp dport { 22, 8384 } accept
    '';
  };

  # Certbot — certificates via LuaDNS DNS-01 challenge
  nixie.certbot = {
    enable = true;
    domains = [ "gammu.home.matos.cc" ];
    syncthingDeploy = true;
  };
}
