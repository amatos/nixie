# Deploys Ghostty's commercial theme files from nix-secrets into the primary
# user's ~/.config/ghostty/themes directory. Path differs by platform:
# /Users/<user> on darwin, /home/<user> on NixOS.
{
  pkgs,
  nix-secrets,
  ...
}:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
  home = if pkgs.stdenv.isDarwin then "/Users/${primaryUser}" else "/home/${primaryUser}";
  themes = [
    "alucard"
    "blade"
    "buffy"
    "dracula"
    "lincoln"
    "morbius"
    "pro"
    "van-helsing"
  ];
in
{
  sops.secrets = builtins.listToAttrs (
    map (theme: {
      name = "ghostty-theme-${theme}";
      value = {
        sopsFile = "${nix-secrets}/ghostty-themes.yaml";
        key = theme;
        path = "${home}/.config/ghostty/themes/${theme}";
        owner = primaryUser;
        mode = "0400";
      };
    }) themes
  );
}
