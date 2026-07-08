# Gammu-specific home-manager settings for alberth.
# krb5 is provided by nixos.nix for all NixOS hosts.
{ pkgs, lib, ... }:

let
  steamupWidth = 3840;
  steamupHeight = 2160;
in
{
  programs.qmd.enable = true;

  # Gammu-only packages
  home.packages = [
    pkgs.act # Run GitHub Actions locally
    pkgs.claude-code # Anthropic's Claude Code CLI; see claude-local below
    pkgs.ioskeley-mono.normal # Ioskeley Mono — Iosevka config mimicking Berkeley Mono
    pkgs.ioskeley-mono.normal-NF # ...with Nerd Font glyphs patched in
    pkgs.ioskeley-mono.normal-term # ...term variant (fixes arrow/box-drawing in Ghostty)
    pkgs.ioskeley-mono.normal-term-NF # ...term variant with Nerd Font glyphs patched in
    pkgs.iosevka # Iosevka monospace font
    pkgs.nerdctl # Docker-compatible CLI for containerd
  ];

  # claude-local — runs Claude Code against the local Ollama model
  # (services.ollama on this host, see hosts/nixos/gammu/default.nix)
  # instead of Anthropic's cloud API. Ollama exposes an Anthropic
  # Messages-API-compatible endpoint directly, so no translation proxy
  # is needed — just point ANTHROPIC_BASE_URL at it. ANTHROPIC_API_KEY is
  # cleared so an already-logged-in cloud session doesn't take priority.
  programs.fish.functions.claude-local = {
    description = "Run Claude Code against the local Ollama model";
    body = ''
      set -x ANTHROPIC_BASE_URL http://localhost:11434
      set -x ANTHROPIC_AUTH_TOKEN ollama
      set -x ANTHROPIC_API_KEY ""
      set -x ANTHROPIC_MODEL qwen2.5-coder:14b
      set -x ANTHROPIC_DEFAULT_HAIKU_MODEL qwen2.5-coder:14b
      claude $argv
    '';
  };

  # steamup — headless gamescope + Steam Big Picture session for Steam
  # Remote Play, as alberth. gamescope's `headless` backend creates no
  # physical or virtual display, so this needs nothing plugged in.
  #
  # gamescope is ExecStart's main process (Type = "exec") — not a detaching
  # wrapper script — so systemd tracks its actual PID: `systemctl --user
  # start/stop/restart steamup` really starts/stops/restarts the session,
  # and stopping it also kills Steam and any running game underneath via
  # systemd's default KillMode (control-group), no manual `pkill` needed.
  # Logs go to the journal (`journalctl --user -u steamup -f`) instead of a
  # log file.
  #
  # /run/current-system/sw/bin/{gamescope,steam} — not ${pkgs.gamescope} /
  # ${pkgs.steam} — because programs.gamescope/programs.steam
  # (hosts/nixos/gammu/default.nix) wrap those packages (capSysNice,
  # extraCompatPackages, FHS env, etc.) and publish only the wrapped result
  # into environment.systemPackages; home-manager's own pkgs would resolve
  # to the plain, unwrapped derivations instead.
  #
  # A user unit (not a NixOS systemd.service with User=) so it runs inside
  # alberth's real systemd --user session — giving it the actual
  # XDG_RUNTIME_DIR/D-Bus session Steam's -pipewire-dmabuf flag needs — with
  # users.users.alberth.linger = true (hosts/nixos/gammu/default.nix)
  # starting that session at boot without an interactive login.
  systemd.user.services.steamup = {
    Unit = {
      Description = "Headless gamescope + Steam Big Picture session for Remote Play";
    };
    Service = {
      Type = "exec";
      ExecStart = ''
        /run/current-system/sw/bin/gamescope \
          -W ${toString steamupWidth} -H ${toString steamupHeight} \
          -w ${toString steamupWidth} -h ${toString steamupHeight} \
          --backend headless \
          --steam \
          -- /run/current-system/sw/bin/steam -tenfoot -pipewire-dmabuf
      '';
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # nerdctl — transparent sudo so rootful containerd works as non-root.
  # home.shellAliases (not programs.fish.shellAliases) so it applies to
  # bash and zsh too, not just fish.
  home.shellAliases = {
    nerdctl = "sudo nerdctl";
  };

  # KDE has no MIME-type mechanism for "default terminal" (a terminal has no
  # associated file type, so mimeapps.list doesn't apply) — the only setting
  # respected by Dolphin's "Open Terminal Here" and similar actions is
  # TerminalApplication/TerminalService in kdeglobals. kdeglobals also holds
  # many settings Plasma itself writes at runtime (theme, fonts, click
  # behavior, etc.), so it isn't home-manager-owned wholesale like a typical
  # dotfile — merge just these two keys in with kwriteconfig6 instead, the
  # same pattern KDE's own System Settings uses under the hood.
  home.activation.setDefaultTerminal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group General --key TerminalApplication ghostty
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group General --key TerminalService com.mitchellh.ghostty.desktop
  '';
}
