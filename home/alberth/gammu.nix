# Gammu-specific home-manager settings for alberth.
# krb5 is provided by nixos.nix for all NixOS hosts.
{ pkgs, lib, ... }:

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
