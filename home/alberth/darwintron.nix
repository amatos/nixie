# Darwintron-specific home-manager settings for alberth.
# Darwin platform essentials: pinentry-mac for GPG, ghostty terminal.
{ pkgs, ... }:

{
  imports = [
    ./darwin
  ];

  # GPG agent — use pinentry-mac for native macOS Keychain / Touch ID prompts.
  services.gpg-agent = {
    enable = true;
    extraConfig = ''
      pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
    '';
  };

  # ghostty.nix provides shared settings; command overrides the default shell lookup.
  programs.ghostty = {
    enable = true;
    package = null; # no aarch64-darwin build in nixpkgs; installed via homebrew cask
    settings.command = "/etc/profiles/per-user/alberth/bin/fish";
  };
}
