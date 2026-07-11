# Ensure ~/.config/ghostty/themes is owned by the primary user before agenix
# places the decrypted theme files there. Without this, agenix (running as
# root) creates the directory as root, which then blocks the user (or
# home-manager) from writing other files into it.
# tmpfiles runs before agenix on NixOS; darwin has no systemd, so this is
# kept out of modules/common/ghostty-theme-secrets.nix and only imported
# here — matches modules/nixos/github-secrets-tmpfiles.nix's rationale.
_:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
  home = "/home/${primaryUser}";
in
{
  systemd.tmpfiles.rules = [
    "d ${home}/.config/ghostty 0755 ${primaryUser} users - -"
    "d ${home}/.config/ghostty/themes 0755 ${primaryUser} users - -"
  ];
}
