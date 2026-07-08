# Shared configuration for all nix-darwin hosts.
# Each host imports this file and adds its hostname, host-specific overlay
# (nixie-homes' homeModules.alberth-<host>), and any host-only services on top.
{
  config,
  lib,
  pkgs,
  nvf,
  qmd,
  nix-secrets,
  stylix,
  nixie-homes,
  ...
}:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  imports = [
    ../../modules/darwin/users.nix
    ../../modules/darwin/sudo.nix
    ../../modules/darwin/macos-defaults
    ../../modules/common/packages.nix
    ../../modules/common/age-host-key.nix
    ../../modules/common/secrets.nix
    ../../modules/common/github-secrets.nix
    ../../modules/common/cachix-secrets.nix
    ../../modules/common/krb5-client.nix
  ];

  # Primary user — required by options that run under the user context (e.g. homebrew)
  system.primaryUser = primaryUser;

  # Determinate Nix forces nix.enable = false on darwin, so nix-darwin never
  # writes /etc/nix/nix.conf — the nix.settings.trusted-users block in
  # modules/common/packages.nix is silently dropped here (it only takes
  # effect on NixOS, where Determinate redirects the generated nix.conf into
  # nix.custom.conf automatically). On darwin, custom settings must go
  # through determinateNix.customSettings instead, which Determinate Nixd
  # writes to /etc/nix/nix.custom.conf directly.
  determinateNix.customSettings = {
    trusted-users = [
      "root"
      primaryUser
      "@admin" # admin users
      "@staff" # all local user accounts
    ];
    # Allow substituters declared in flake nixConfig blocks (e.g. ragenix,
    # home-manager, zed). Without this, the daemon ignores those caches even
    # for users already in trusted-users — trusted-users only covers caches
    # the user specifies in their own nix config, not flake-sourced ones.
    accept-flake-config = true;
  };

  # Allow Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Fish — default login shell; enabled system-wide so it appears in /etc/shells.
  # Zsh remains available (kept for scripts and compatibility).
  programs.fish.enable = true;
  programs.zsh.enable = true;
  users.users.${primaryUser}.shell = pkgs.fish;

  # Zapp — CLI tool for flashing ZSA keyboards
  programs.zapp.enable = true;

  # NTP — sync from porkchop over Tailscale. macOS timed does not support NTS and
  # only accepts a single server (set via systemsetup); porkchop still provides
  # authenticated upstream sync. Tailscale hostname is preferred over LAN because
  # it is reachable from any network.
  #
  # nix-darwin's /activate script is assembled from a fixed list of named
  # stages (see modules/system/activation-scripts.nix upstream) — arbitrary
  # custom activationScripts.<name> keys (like the old `ntp` key here) are
  # evaluated but silently never run. extraActivation is the supported
  # extension point.
  # Postfix relay client — relay all outbound mail through porkchop.
  # macOS ships postfix but nix-darwin has no services.postfix module.
  # We use postconf -e in the activation script to write specific keys into
  # the existing /etc/postfix/main.cf without owning the whole file (same
  # pattern as kwriteconfig6 for KDE settings), and register a launchd daemon
  # so postfix starts on demand when mail is queued to the maildrop directory.
  launchd.daemons."org.postfix.master" = {
    serviceConfig = {
      Label = "org.postfix.master";
      # postfix master process — exits after 60 s of idle; launchd restarts
      # it when the next message arrives in the maildrop queue directory.
      ProgramArguments = [
        "/usr/libexec/postfix/master"
        "-e"
        "60"
      ];
      QueueDirectories = [ "/private/var/spool/postfix/maildrop" ];
      KeepAlive = false;
      StandardErrorPath = "/dev/null";
    };
  };

  system.activationScripts.extraActivation.text = lib.mkAfter ''
    echo "configuring NTP server..." >&2
    systemsetup -setnetworktimeserver "porkchop.ts.matos.cc" 2>/dev/null || true
    systemsetup -setusingnetworktime on 2>/dev/null || true

    echo "configuring postfix relay client..." >&2
    /usr/sbin/postconf -e 'relayhost = [porkchop.ts.matos.cc]:25'
    /usr/sbin/postconf -e 'inet_interfaces = loopback-only'
    /usr/sbin/postconf -e 'inet_protocols = all'
    /usr/sbin/postconf -e 'mydestination = '
    /usr/sbin/postconf -e 'local_transport = error:local delivery disabled'
    /usr/sbin/postconf -e 'smtp_tls_security_level = may'
    /usr/sbin/postfix set-permissions 2>/dev/null || true
  '';

  # LDAP client — disable SASL hostname canonicalization (same reason as
  # NixOS; see common-nixos.nix).  macOS ldap tools read /etc/ldap.conf.
  environment.etc."ldap.conf".text = ''
    SASL_NOCANON on
  '';

  # SSH daemon — password auth disabled; GSSAPI enabled for Kerberos auth.
  # macOS manages its own firewall separately; no networking.firewall equivalent in nix-darwin.
  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      PermitRootLogin no
      GSSAPIAuthentication yes
      GSSAPICleanupCredentials yes
    '';
  };

  # Install Nix-managed apps as macOS aliases in /Applications/Nix Apps/.
  # Native aliases are indexed by Spotlight and Launchpad unlike Unix symlinks.
  system.activationScripts.applications.text =
    let
      env = pkgs.buildEnv {
        name = "system-applications";
        paths = config.environment.systemPackages;
        pathsToLink = [ "/Applications" ];
      };
    in
    lib.mkForce ''
      echo "setting up /Applications/Nix Apps..." >&2
      rm -rf /Applications/Nix\ Apps
      mkdir -p /Applications/Nix\ Apps
      find ${env}/Applications -maxdepth 1 -type l | while read -r app; do
        src=$(readlink "$app")
        name=$(basename "$app")
        echo "  aliasing $name" >&2
        ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$name"
      done
    '';

  # home-manager — base config shared by all darwin hosts.
  # Each host merges in its own overlay via:
  #   home-manager.users.${primaryUser} = { imports = [ nixie-homes.homeModules.alberth-<host> ]; };
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupCommand = "${pkgs.trash-cli}/bin/trash";
    sharedModules = [
      nvf.homeManagerModules.default
      qmd.homeModules.default
      stylix.homeModules.stylix
    ];
    extraSpecialArgs = { inherit nix-secrets; };
    users.${primaryUser} = {
      imports = [
        nixie-homes.homeModules.alberth
        nixie-homes.homeModules.alberth-nvf
      ];
      # openssh_gssapi shadows pkgs.openssh (added to PATH by nix-darwin's
      # services.openssh) so the SSH client supports GSSAPIAuthentication.
      home.packages = [ pkgs.openssh_gssapi ];
    };
  };

  # Set when the host was first provisioned — do not change after initial deploy.
  system.stateVersion = 5;
}
