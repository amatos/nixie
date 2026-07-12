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
  inherit (userDefs) primaryUser;
in

{
  imports = [
    ../../modules/nixos/users.nix
    ../../modules/nixos/home-manager.nix
    ../../modules/nixos/certbot.nix
    ../../modules/nixos/ghostty.nix
    ../../modules/nixos/agenix-fix.nix
    ../../modules/nixos/user-passwords.nix
    ../../modules/nixos/sudo.nix
    ../../modules/nixos/github-secrets-tmpfiles.nix
    ../../modules/nixos/ghostty-theme-tmpfiles.nix
    ../../modules/common/packages.nix
    ../../modules/common/age-host-key.nix
    ../../modules/common/secrets.nix
    ../../modules/common/github-secrets.nix
    ../../modules/common/tailscale-secrets.nix
    ../../modules/common/cachix-secrets.nix
    ../../modules/common/ghostty-theme-secrets.nix
    ../../modules/common/krb5-client.nix
  ];

  networking = {
    useDHCP = true;
    nftables.enable = true;
    firewall = {
      # Trust all traffic arriving on the Tailscale interface
      trustedInterfaces = [ "tailscale0" ];
      # Allow SSH through the firewall only when the firewall is active
      allowedTCPPorts = lib.mkIf config.networking.firewall.enable [ 22 ];
    };
  };

  services = {
    tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscale-authkey.path;
    };

    # SSH daemon — password auth disabled; GSSAPI enabled for Kerberos auth.
    # openssh_gssapi is required: pkgs.openssh no longer includes GSSAPI support;
    # the option is a separate Debian patch applied only in the _gssapi derivation.
    openssh = {
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
    chrony = lib.mkIf (config.networking.hostName != "porkchop") {
      enable = true;
      servers = [ ];
      extraConfig = ''
        server porkchop.ts.matos.cc iburst nts
      '';
    };

    # Postfix relay client — relay all outbound mail through porkchop.
    # porkchop runs the full smtp-relay module (modules/nixos/smtp-relay.nix)
    # and manages postfix itself; all other NixOS hosts use it as a smarthost
    # over Tailscale on port 25. porkchop's myNetworks covers both the LAN
    # subnet (10.0.4.0/22) and Tailscale CGNAT (100.64.0.0/10), so no SASL
    # credentials are required from fleet hosts.
    postfix = lib.mkIf (config.networking.hostName != "porkchop") {
      enable = true;
      settings.main = {
        # Listen on loopback only — this is a client, not a relay
        inet_interfaces = "loopback-only";
        inet_protocols = "all";
        # Relay all mail through porkchop via Tailscale hostname
        relayhost = [ "[porkchop.ts.matos.cc]:25" ];
        # Disable local delivery
        mydestination = "";
        local_transport = "error:local delivery disabled";
        # Opportunistic TLS toward porkchop
        smtp_tls_security_level = "may";
      };
    };
  };

  # Latest stable kernel — override per-host if hardware requires a specific version
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    # Bootloader — systemd-boot for EFI systems
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # Locale / timezone — override per-host if needed
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Disable the local NixOS manual/options-search JSON build. Not used day
  # to day (docs are read on search.nixos.org / via CLAUDE.md), it adds to
  # eval/build time, and it's the source of the upstream
  # `builtins.toFile ... options.json ... without a proper context` warning
  # (nixpkgs#485682) that fires on every `nix flake check`/`nix flake update`.
  documentation.nixos.enable = false;

  # Fish — default login shell. /etc/shells is managed fleet-wide in
  # modules/common/packages.nix (environment.shells).
  # Zsh remains available (kept for scripts and compatibility).
  programs = {
    fish.enable = true;
    zsh.enable = true;
    # Zapp — CLI tool for flashing ZSA keyboards; also installs udev rules
    zapp.enable = true;
  };
  users.users.${primaryUser}.shell = pkgs.fish;

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

  # Set when the host was first provisioned — do not change after initial deploy.
  # Override per-host if a machine was set up at a different NixOS release.
  system.stateVersion = "26.05";
}
