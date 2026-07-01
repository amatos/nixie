# Gammu-specific home-manager settings for alberth.
# krb5 is provided by nixos.nix for all NixOS hosts.
{ pkgs, lib, ... }:

{
  # Gammu-only packages
  home.packages = [
    pkgs.act # Run GitHub Actions locally
    pkgs.nerdctl # Docker-compatible CLI for containerd
  ];

  # nerdctl — transparent sudo so rootful containerd works as non-root
  programs.fish.shellAliases = {
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
