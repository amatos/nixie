# Shared configuration for all NixOS hosts.
# Each host imports this file and adds only its hardware-configuration.nix
# and networking.hostName on top.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  userDefs = import ../../users.nix;
  primaryUser = userDefs.primaryUser;
in

{
  imports = [
    ../../modules/nixos/users.nix
    ../../modules/nixos/home-manager.nix
    ../../modules/nixos/certbot.nix
    ../../modules/nixos/ghostty.nix
    ../../modules/nixos/agenix-fix.nix
    ../../modules/nixos/default-password.nix
    ../../modules/nixos/sudo.nix
    ../../modules/common/packages.nix
    ../../modules/common/age-host-key.nix
    ../../modules/common/secrets.nix
    ../../modules/common/github-secrets.nix
    ../../modules/common/tailscale-secrets.nix
    ../../modules/common/cachix-secrets.nix
    ../../modules/common/krb5-client.nix
  ];

  networking.useDHCP = true;
  networking.nftables.enable = true;

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-authkey.path;
  };

  # Trust all traffic arriving on the Tailscale interface
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Latest stable kernel — override per-host if hardware requires a specific version
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Bootloader — systemd-boot for EFI systems
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Locale / timezone — override per-host if needed
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Fish — enable system-wide so it appears in /etc/shells and can be set as login shell
  programs.fish.enable = true;
  users.users.${primaryUser}.shell = pkgs.fish;

  # Zapp — CLI tool for flashing ZSA keyboards; also installs udev rules
  programs.zapp.enable = true;

  # SSH daemon — password auth disabled; GSSAPI enabled for Kerberos auth.
  # openssh_gssapi is required: pkgs.openssh no longer includes GSSAPI support;
  # the option is a separate Debian patch applied only in the _gssapi derivation.
  services.openssh = {
    enable = true;
    package = pkgs.openssh_gssapi;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      GSSAPIAuthentication = true;
      GSSAPICleanupCredentials = true;
    };
  };

  # NTP — all hosts except porkchop sync from porkchop via NTS over Tailscale.
  # porkchop runs its own chrony server (configured in hosts/nixos/porkchop/default.nix)
  # and upstreams to Cloudflare/Google, so this block is skipped there.
  services.chrony = lib.mkIf (config.networking.hostName != "porkchop") {
    enable = true;
    servers = [ ];
    extraConfig = ''
      server porkchop.ts.matos.cc iburst nts
    '';
  };

  # LDAP client — disable SASL hostname canonicalization.
  # The SASL GSSAPI plugin resolves the server hostname via reverse DNS
  # before constructing the service principal.  On Tailscale this yields
  # the tailnet-internal domain (e.g. porkchop.tail<id>.ts.net) instead
  # of the FQDN in the URL, causing a cross-realm referral to a
  # non-existent realm.  SASL_NOCANON tells libldap to use the URL
  # hostname literally so the correct ldap/porkchop.ts.matos.cc@MATOS.CC
  # principal is requested.
  environment.etc."openldap/ldap.conf".text = ''
    SASL_NOCANON on
  '';

  # Allow SSH through the firewall only when the firewall is active
  networking.firewall.allowedTCPPorts = lib.mkIf config.networking.firewall.enable [ 22 ];

  # Set when the host was first provisioned — do not change after initial deploy.
  # Override per-host if a machine was set up at a different NixOS release.
  system.stateVersion = "26.05";
}
