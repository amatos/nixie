# NixOS-specific home-manager settings for alberth.
{ pkgs, ... }:

{
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
