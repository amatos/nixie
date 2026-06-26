# Codex-specific home-manager settings for alberth.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # GPG agent — use pinentry-mac for native macOS Keychain / Touch ID prompts.
  # pinentry-mac is also in homebrew.brews so it's available system-wide;
  # we point gpg-agent at the nixpkgs derivation for a deterministic path.
  services.gpg-agent = {
    enable = true;
    extraConfig = ''
      pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
    '';
  };

  imports = [
    ./ghostty.nix
  ];

  # Ghostty — installed via homebrew cask; enable programs.ghostty so
  # home-manager can manage the config and catppuccin can inject the theme.
  # package = null prevents home-manager from installing the nixpkgs build,
  # which has no aarch64-darwin support.
  # ghostty.nix provides all default settings; override specific keys here.
  programs.ghostty = {
    enable = true;
    package = null;
    settings.command = "/etc/profiles/per-user/alberth/bin/fish";
  };
  catppuccin.ghostty.enable = true;

  programs.ssh.settings = {
    "*" = {
      ServerAliveInterval = 120;
      IdentityAgent = ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
      ForwardAgent = true;
    };
    "muninn.home.matos.cc muninn.local muninn" = {
      User = "pi";
    };
  };

  # Prepend `Include 1Password/config` to the top of ~/.ssh/config after
  # home-manager writes it. extraConfig appends to the end, so we use an
  # activation script instead to ensure SSH processes the include first.
  home.activation.prependSSHInclude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    sshConfig="${config.home.homeDirectory}/.ssh/config"
    tmpfile=$(mktemp)
    { printf 'Include 1Password/config\n\n'; cat "$sshConfig"; } > "$tmpfile"
    chmod 600 "$tmpfile"
    mv "$tmpfile" "$sshConfig"
  '';
}
