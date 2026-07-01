# Shared home-manager settings for all nix-darwin hosts.
# Imported by every darwin host overlay (codex.nix, darwintron.nix, etc.)
# via `imports = [ ./darwin ];`.
#
# Host overlays only need to add settings that genuinely differ between hosts.
{ pkgs, ... }:

{
  imports = [
    ./ghostty.nix
  ];

  # GPG agent — use pinentry-mac for native macOS Keychain / Touch ID prompts.
  # pinentry-mac is also available via homebrew brew on hosts that use Homebrew;
  # we point gpg-agent at the nixpkgs derivation for a deterministic path.
  services.gpg-agent = {
    enable = true;
    extraConfig = ''
      pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
    '';
  };

  # Ghostty terminal — installed via homebrew cask on all darwin hosts.
  # package = null prevents home-manager from installing the nixpkgs build,
  # which has no aarch64-darwin support. ghostty.nix provides shared settings;
  # command is left unset so Ghostty launches the user's default login shell
  # (users.users.<name>.shell, now zsh — see common-darwin.nix).
  programs.ghostty = {
    enable = true;
    package = null;
  };
}
