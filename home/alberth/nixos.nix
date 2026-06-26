# NixOS-specific home-manager settings for alberth.
{ lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    _1password-gui # 1Password desktop app
    _1password-cli # 1Password CLI (op)
  ];

  home.shellAliases = {
    open = "xdg-open";
  };

  # Mask the syncthing user unit shipped by the syncthing package.
  # services.syncthing on NixOS runs syncthing as a system service; the package
  # also installs a user unit (WantedBy=default.target) which conflicts with it.
  home.activation.maskSyncthingUserService = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/systemd/user"
    ln -sf /dev/null "$HOME/.config/systemd/user/syncthing.service"
  '';

  # GPG agent — use plain-text pinentry suitable for TTY / SSH sessions.
  services.gpg-agent = {
    enable = true;
    extraConfig = ''
      pinentry-program ${pkgs.pinentry-tty}/bin/pinentry-tty
    '';
  };
}
