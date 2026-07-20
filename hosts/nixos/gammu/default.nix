{
  pkgs,
  lib,
  nix-keytabs-matos-cc,
  ...
}:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  imports = [
    ./hardware-configuration.nix
    ../common-nixos.nix
    ../../../modules/common/certbot-secrets.nix
    ../../../modules/common/development-packages.nix
    ../../../modules/nixos/syncthing-password.nix
    ../../../modules/nixos/syncthing-healthcheck.nix
  ];

  networking.hostName = "gammu";

  # Steam — 32-bit graphics support is required or Steam fails to start.
  # AMD GPU (radv, via mesa) needs no extra driver packages.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server hosting
      extraCompatPackages = with pkgs; [ proton-ge-bin ]; # Custom Proton build with extra game fixes
      gamescopeSession.enable = true; # Steam Big Picture session launchable via gamescope
    };

    # GameMode — applies temporary perf tweaks (CPU governor, etc.) while a game runs
    gamemode.enable = true;

    # Gamescope — micro-compositor backing the Steam gamescope session above
    gamescope = {
      enable = true;
      capSysNice = false;
    };
  };

  # rocm-smi — CLI for querying/monitoring the AMD GPU (name, VRAM usage,
  # clocks, temps). Any NixOS host with an AMD graphics card should carry
  # this; gammu is currently the only one.
  # nixd — Nix language server, for editor tooling (Zed, nvf).
  environment.systemPackages = [
    pkgs.rocmPackages.rocm-smi
    pkgs.nixd
  ];

  # GDM is configured (for xrdp's GNOME session, below) but must not launch
  # automatically at boot — this host is normally accessed headlessly over
  # SSH/RDP, not via a local console login screen. graphical.target normally
  # pulls in display-manager.service; dropping that wantedBy leaves gdm
  # startable on demand only (`systemctl start display-manager`).
  systemd.services.display-manager.wantedBy = lib.mkForce [ ];

  services = {
    displayManager.gdm.enable = true;
    xserver = {
      desktopManager.gnome.enable = true;
      # xrdp — remote access into GNOME over RDP for streaming to codex.
      # Requires services.xserver.enable = true: xrdp's session is a separate
      # X11 GNOME instance, independent of any local Wayland session — both
      # can run at once.
      enable = true;
    };
    xrdp = {
      enable = true;
      # Plain "gnome-session" (resolved off xrdp's own PATH) leaves the RDP
      # session at a black screen: xrdp's Xorg/session script doesn't start a
      # D-Bus session bus itself, and GNOME's components fail to come up
      # without one. Launching gnome-session under dbus-run-session gives it
      # that bus explicitly; both packages are referenced via their store paths
      # so this doesn't depend on anything being on xrdp's PATH.
      defaultWindowManager = "${pkgs.dbus}/bin/dbus-run-session ${pkgs.gnome-session}/bin/gnome-session";
      openFirewall = true;
      # Let's Encrypt cert (gammu.ts.matos.cc) via nixie.certbot.xrdpDeploy below, instead of
      # xrdp's default self-signed cert.
      sslCert = "/var/lib/xrdp-tls/fullchain.pem";
      sslKey = "/var/lib/xrdp-tls/privkey.pem";
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
    syncthing = {
      enable = true;
      user = primaryUser;
      dataDir = "/home/${primaryUser}";
      guiAddress = "0.0.0.0:8384";
      overrideDevices = false;
      overrideFolders = false;
      settings = {
        gui = {
          user = "syncthing";
          address = "0.0.0.0:8384";
        };
        options.listenAddresses = [
          "tcp://0.0.0.0:22000"
          "quic://0.0.0.0:22000"
        ];
      };
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
    ollama = {
      enable = true;
      package = pkgs.ollama-rocm;
      rocmOverrideGfx = "11.0.1";
      host = "0.0.0.0";
      port = 11434;

      # qwen2.5-coder:14b (~9GB at Q4_K_M) fits the 12GB VRAM on this card
      # with headroom for KV cache; chosen for reliable tool-calling support
      # in both Zed's Agent Panel and Claude Code (via Ollama's Anthropic-
      # compatible endpoint, see nix-home-alberth's alberth/gammu.nix `claude-local`).
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
    open-webui = {
      enable = true;
      host = "0.0.0.0";
      port = 8080;
      environment = {
        OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      };
    };

    # Orion Browser (Kagi) — no first-party Linux release beyond a standalone
    # Flatpak bundle (not on Flathub, no AppImage/deb/rpm); packaged in
    # github:amatos/nix-orion-browser as a hash-pinned wrapper. Enabling this
    # also turns on services.flatpak.enable; xdg.portal.enable is already true
    # here via services.xserver.desktopManager.gnome.
    orion-browser.enable = true;
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
    # systemd.user.services.steam (nix-home-alberth's alberth/gammu.nix) to autostart
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
    xrdpDeploy = true;
  };

  nixie.krb5.keytabFile = "${nix-keytabs-matos-cc}/keytab-gammu.age";
}
