{ pkgs, keytabs-matos-cc, ... }:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;

  # Launches a headless gamescope + Steam Big Picture session at 4K for
  # Steam Remote Play — see modules/common conventions in CLAUDE.md.
  steamupScript = pkgs.writeShellApplication {
    name = "steamup.sh";
    runtimeInputs = [ ]; # gamescope/steam come from programs.gamescope/programs.steam on PATH
    text = builtins.readFile ./scripts/steamup.sh;
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ../common-nixos.nix
    ../../../modules/common/certbot-secrets.nix
    ../../../modules/nixos/syncthing-password.nix
  ];

  networking.hostName = "gammu";

  # Steam — 32-bit graphics support is required or Steam fails to start.
  # AMD GPU (radv, via mesa) needs no extra driver packages.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
    extraCompatPackages = with pkgs; [ proton-ge-bin ]; # Custom Proton build with extra game fixes
    gamescopeSession.enable = true; # Steam Big Picture session launchable via gamescope
  };

  # GameMode — applies temporary perf tweaks (CPU governor, etc.) while a game runs
  programs.gamemode.enable = true;

  # Gamescope — micro-compositor backing the Steam gamescope session above
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # steamup.sh — ad-hoc headless launcher for Steam Remote Play (SSH in, run
  # `steamup.sh`); see hosts/nixos/gammu/scripts/steamup.sh
  environment.systemPackages = [ steamupScript ];

  # KDE Plasma — desktop environment. SDDM starts automatically at boot
  # (systemd default target flips to graphical.target when a display manager
  # is enabled) and shows a login screen; no autologin. This also makes the
  # Steam gamescope Big Picture session (programs.steam.gamescopeSession
  # above) selectable from SDDM's session picker.
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # xrdp — remote access into Plasma over RDP for streaming to codex.
  # Requires services.xserver.enable = true: xrdp's session is a separate
  # X11 (not Wayland) Plasma instance, independent of SDDM's local Wayland
  # session above — both can run at once.
  services.xserver.enable = true;
  services.xrdp = {
    enable = true;
    defaultWindowManager = "startplasma-x11";
    openFirewall = true;
  };

  # containerd — container runtime; starts automatically via systemd
  virtualisation.containerd.enable = true;

  # Docker — uses containerd as backend; provides the Docker API socket
  # that act requires. User added to docker group for socket access.
  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };
  users.users.${primaryUser}.extraGroups = [ "docker" ];

  # Allow primaryUser to run nerdctl as root without a password prompt.
  # nerdctl v2 requires root for rootful containerd regardless of socket perms.
  environment.etc."sudoers.d/nerdctl" = {
    text = ''
      ${primaryUser} ALL=(ALL:ALL) NOPASSWD: /etc/profiles/per-user/${primaryUser}/bin/nerdctl
    '';
    mode = "0440";
  };

  # Syncthing — runs as a systemd service, syncs to the primary user's home.
  # GUI password is managed via syncthing-password.nix (ragenix secret).
  #
  # guiAddress/settings.gui.address use the IPv4 wildcard "0.0.0.0", not the
  # IPv6 wildcard "[::]": NixOS's syncthing-init service (merge-syncthing-config)
  # curls this same address to reconcile declared settings, and connecting TO
  # a literal "::" destination fails outright ("Failed to connect to :: port
  # 8384") since IPv6 has no equivalent of Linux's 0.0.0.0-connects-to-loopback
  # behavior. 0.0.0.0 works for both binding (all IPv4 interfaces) and as a
  # connect target (kernel routes it over loopback) — see CLAUDE.md Syncthing
  # conventions. This does mean the GUI is IPv4-only.
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

  # Firewall — restrict SSH and Syncthing GUI to the local subnet;
  # Syncthing sync protocol (22000) open globally for peer connectivity
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 ];
    extraInputRules = ''
      ip  saddr 10.0.4.0/22 tcp dport 8384 accept
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

  nixie.krb5.keytabFile = "${keytabs-matos-cc}/keytab-gammu.age";
}
