{ ... }:

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
  };

  # Certbot — certificates via LuaDNS DNS-01 challenge
  nixie.certbot = {
    enable = true;
    domains = [ "gammu.home.matos.cc" ];
    syncthingDeploy = true;
  };
}
