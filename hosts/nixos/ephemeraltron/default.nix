# Minimal template NixOS host.
# Purpose: come online at a known IP so a real configuration can be applied via:
#   nixos-rebuild switch --flake github:amatos/nixie#<hostname>
# This config intentionally omits ragenix, home-manager, certbot, and Tailscale
# — those are all provided by the real config applied after provisioning.
{ pkgs, ... }:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
  user = userDefs.${primaryUser};
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "ephemeraltron";

  # Static IP — disable DHCP and predictable interface names so the NIC is eth0
  networking.useDHCP = false;
  networking.usePredictableInterfaceNames = false;
  networking.interfaces.eth0.ipv4.addresses = [
    {
      address = "10.0.6.66";
      prefixLength = 22;
    }
  ];
  networking.defaultGateway = "10.0.4.1";
  networking.nameservers = [ "10.0.4.1" ];
  networking.nftables.enable = true;

  # Firewall — SSH only
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # EFI bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Timezone and locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Zsh — register as a login shell
  programs.zsh.enable = true;

  # Primary user — key sourced from users.nix
  users.users.${primaryUser} = {
    isNormalUser = true;
    inherit (user) description;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = user.openssh.authorizedKeys.keys;
  };

  # Passwordless sudo for wheel — needed to run nixos-rebuild after SSH in
  security.sudo.wheelNeedsPassword = false;

  # SSH — key-only, no root login
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Nix — enable flakes so nixos-rebuild --flake works immediately after provisioning
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      primaryUser
    ];
  };

  # Minimal toolset for post-install config application
  environment.systemPackages = with pkgs; [
    git
    curl
    vim
  ];

  # Set when this template was defined — do not change.
  system.stateVersion = "26.05";
}
