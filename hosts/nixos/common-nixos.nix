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
    ../../modules/nixos/user-passwords.nix
    ../../modules/nixos/sudo.nix
    ../../modules/nixos/github-secrets-tmpfiles.nix
    ../../modules/nixos/ghostty-theme-tmpfiles.nix
    ../../modules/common/packages.nix
    ../../modules/common/github-secrets.nix
    ../../modules/common/tailscale-secrets.nix
    ../../modules/common/cachix-secrets.nix
    ../../modules/common/ghostty-theme-secrets.nix
    ../../modules/common/krb5-client.nix
  ];

  networking = {
    # mkDefault (not a bare `true`): services.xserver.desktopManager.gnome.enable
    # (gammu) auto-enables networking.networkmanager.enable, which itself sets
    # networking.useDHCP = mkDefault false so NetworkManager alone owns DHCP.
    # A hardcoded `true` here would outrank that default and fight
    # NetworkManager over the interface; mkDefault keeps plain dhcpcd as the
    # fleet-wide default while yielding to NetworkManager on hosts that pull
    # it in.
    useDHCP = lib.mkDefault true;
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
      authKeyFile = config.sops.secrets.tailscale-authkey.path;
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

    # Postfix relay client — relay all outbound mail through huginn (primary),
    # falling back to porkchop if huginn is unreachable. huginn and porkchop
    # both run the full smtp-relay module (modules/nixos/smtp-relay.nix) and
    # manage postfix themselves; every other NixOS host uses this client
    # config instead — so the guard excludes both server-role hosts, since
    # their own smtp-relay.nix config would otherwise conflict with this one
    # on the same postfix options. Both huginn's and porkchop's myNetworks
    # cover the LAN subnet (10.0.4.0/22) and Tailscale CGNAT (100.64.0.0/10),
    # so no SASL credentials are required from fleet hosts either way.
    postfix =
      lib.mkIf
        (
          !(builtins.elem config.networking.hostName [
            "porkchop"
            "huginn"
          ])
        )
        {
          enable = true;
          settings.main = {
            # See the environment.etc."postfix-generic-map" comment below and
            # modules/nixos/smtp-relay.nix's module-level comment for why both
            # of these are needed: a mail client that builds its own From
            # address via gethostname() (e.g. mailutils' `mail`) produces a
            # syntactically complete but short-hostname address
            # (alberth@gammu) that myorigin never rewrites, and huginn's own
            # relay forwards it to Fastmail as-is — rejected outright with
            # "need fully-qualified address". Confirmed hitting this from
            # gammu during Stage 6 validation.
            myhostname = "${config.networking.hostName}.home.matos.cc";
            smtp_generic_maps = "texthash:/etc/postfix-generic-map";

            # Listen on loopback only — this is a client, not a relay
            inet_interfaces = "loopback-only";
            inet_protocols = "all";
            # Relay all mail through huginn via Tailscale hostname; fall back to
            # porkchop if huginn doesn't respond (see ARCHITECTURE.md §10 Stage 6).
            relayhost = [ "[huginn.ts.matos.cc]:25" ];
            smtp_fallback_relay = [ "[porkchop.ts.matos.cc]:25" ];
            # Disable local delivery
            mydestination = "";
            local_transport = "error:local delivery disabled";
            # Opportunistic TLS toward the relay
            smtp_tls_security_level = "may";
          };
        };

    # Syslog forwarding client — Stage 7d of ARCHITECTURE.md §10. Ships this
    # host's local syslog/journal messages to porkchop's centralized
    # receiver (Stage 7a) over TCP, via the imuxsock input every rsyslogd
    # instance loads unconditionally (reads journald's syslog-compatible
    # forwarding socket) — no extra input config needed here, just the
    # forward action. Guard excludes only porkchop itself (the receiver);
    # unlike the postfix client guard, huginn doesn't need excluding here
    # since it isn't also running its own syslog receiver.
    rsyslogd = lib.mkIf (config.networking.hostName != "porkchop") {
      enable = true;
      # This host only forwards — skip the default local file layout
      # (dhcpd/mail/warn/messages); porkchop's Grafana is now the place to
      # look, not this host's own /var/log/*.
      defaultConfig = "";
      extraConfig = ''
        action(
          type="omfwd"
          target="porkchop.ts.matos.cc"
          port="514"
          protocol="tcp"
          action.resumeRetryCount="-1"
          queue.type="linkedList"
          queue.filename="fwd_queue"
        )
      '';
    };
  };

  # Generic table rewriting the bare hostname domain to the LAN FQDN on
  # outbound mail — see the postfix client block above. Deliberately a
  # top-level /etc entry, not nested under /etc/postfix/ (that path is a
  # runtime bind-mount NixOS's postfix module manages as a whole unit; see
  # modules/nixos/smtp-relay.nix for the same constraint on the server
  # side). Guarded the same way as the client postfix block, since huginn
  # and porkchop declare their own version of this same file in
  # smtp-relay.nix — both would conflict if this applied unconditionally.
  environment.etc."postfix-generic-map" = lib.mkIf (
    !(builtins.elem config.networking.hostName [
      "porkchop"
      "huginn"
    ])
  ) { text = "@${config.networking.hostName} ${config.networking.hostName}.home.matos.cc\n"; };

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
