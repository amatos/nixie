# template-darwin — darwin host-specific home-manager settings.
# Copy to home/alberth/<hostname>.nix when provisioning a new darwin host.
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

  programs.ghostty = {
    enable = true;
    package = null; # no aarch64-darwin build in nixpkgs; installed via homebrew cask
    settings.command = "/etc/profiles/per-user/alberth/bin/fish";
  };
}
