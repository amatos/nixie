{ pkgs, keytabs-matos-cc, ... }:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
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
    capSysNice = false;
  };

  # rocm-smi — CLI for querying/monitoring the AMD GPU (name, VRAM usage,
  # clocks, temps). Any NixOS host with an AMD graphics card should carry
  # this; gammu is currently the only one.
  environment.systemPackages = [
    pkgs.rocmPackages.rocm-smi
  ];

  # KDE Plasma — desktop environment, but no local display manager: SDDM is
  # disabled so the host boots to a text console rather than a graphical
  # login screen. Plasma is still reachable via xrdp below (X11 session) and
  # the Steam gamescope Big Picture session remains launchable headlessly via
  # the steamup systemd user unit (systemd.user.services.steamup, nixie-homes'
  # alberth/gammu.nix).
  #
  # Disabling sddm alone is NOT sufficient: services.xserver.enable = true
  # below (required for xrdp) also flips services.xserver.displayManager.
  # lightdm.enable to `mkDefault true` via a fallback in nixpkgs'
  # xserver.nix ("enable lightdm unless gdm/sddm/greetd/ly/lemurs/... are
  # enabled") -- since only sddm was disabled, lightdm silently became the
  # actual display manager, and systemd.defaultUnit = "graphical.target"
  # (also set by services.xserver.enable) meant it started at boot despite
  # the comment above. Confirmed via `nix eval
  # .#nixosConfigurations.gammu.config.systemd.services.display-manager.
  # script`, which showed it exec'ing lightdm. Disabling lightdm explicitly
  # here closes that gap -- no other entry in the xserver.nix fallback list
  # is enabled, so systemd.services.display-manager is no longer defined at
  # all (not merely masked).
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = false;
  services.xserver.displayManager.lightdm.enable = false;

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
  users.users.${primaryUser} = {
    extraGroups = [ "docker" ];
    # Lingering — starts primaryUser's systemd --user instance at boot
    # instead of only on interactive login. Required for
    # systemd.user.services.steamup (nixie-homes' alberth/gammu.nix) to autostart
    # headless gamescope + Steam on boot.
    linger = true;
  };

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

  # Ollama — local LLM inference with ROCm acceleration on the AMD GPU.
  # Binds to 0.0.0.0; firewall restricts LAN access below. Tailscale clients
  # reach it via trustedInterfaces = ["tailscale0"] in common-nixos.nix.
  #
  # Card is a Radeon RX 7700 XT (Navi 32, gfx1101, 12GB VRAM) — confirmed via
  # `rocminfo` and /sys/class/drm/card*/device/{device,mem_info_vram_total}
  # on the host. Earlier comments here incorrectly assumed an RX 7900 GRE
  # (Navi 31/gfx1100/16GB) — never verified against the actual hardware.
  # rocmOverrideGfx = "11.0.1" reports the correct gfx1101 target to ROCm.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    rocmOverrideGfx = "11.0.1";
    host = "0.0.0.0";
    port = 11434;

    # qwen2.5-coder:14b (~9GB at Q4_K_M) fits the 12GB VRAM on this card
    # with headroom for KV cache; chosen for reliable tool-calling support
    # in both Zed's Agent Panel and Claude Code (via Ollama's Anthropic-
    # compatible endpoint, see nixie-homes' alberth/gammu.nix `claude-local`).
    # loadModels pulls it declaratively on activation; syncModels stays at
    # its default (false) so ad-hoc `ollama pull` isn't wiped on rebuild.
    loadModels = [ "qwen2.5-coder:14b" ];

    environmentVariables = {
      # 32K floor recommended for agentic tool-call loops (Claude Code's
      # system prompt + tool schemas alone can run 6-10K tokens). Default
      # is dynamic based on VRAM (4k/32k/256k) — pinned here for
      # predictability across model/context changes.
      OLLAMA_CONTEXT_LENGTH = "32768";
    };
  };

  # Open WebUI — browser frontend for Ollama.
  # Binds to 0.0.0.0 on port 8080; points at Ollama on localhost.
  # Accessible from any host via Tailscale or LAN (restricted by firewall).
  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 8080;
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
    };
  };

  # Firewall — restrict SSH and Syncthing GUI to the local subnet;
  # Syncthing sync protocol (22000) open globally for peer connectivity.
  # Ollama (11434) and Open WebUI (8080) restricted to LAN; Tailscale
  # access is covered by trustedInterfaces = ["tailscale0"].
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 ];
    extraInputRules = ''
      ip  saddr 10.0.4.0/22 tcp dport 8384  accept
      ip  saddr 10.0.4.0/22 tcp dport 11434 accept
      ip  saddr 10.0.4.0/22 tcp dport 8080  accept
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
