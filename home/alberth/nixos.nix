# NixOS-specific home-manager settings for alberth.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    _1password-gui # 1Password desktop app
    _1password-cli # 1Password CLI (op)
  ];

  home.shellAliases = {
    open = "xdg-open";
  };

  # GPG agent — use plain-text pinentry suitable for TTY / SSH sessions.
  services.gpg-agent = {
    enable = true;
    extraConfig = ''
      pinentry-program ${pkgs.pinentry-tty}/bin/pinentry-tty
    '';
  };
}
