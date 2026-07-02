# Shared home-manager configuration for all NixOS hosts.
# Each host still imports a platform-specific overlay (home/alberth/nixos.nix)
# via users.<primaryUser> — that file handles NixOS-only divergences (pinentry-tty,
# open alias, etc.).
{
  pkgs,
  nvf,
  catppuccin,
  nix-secrets,
  ...
}:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupCommand = "${pkgs.trash-cli}/bin/trash";
    sharedModules = [
      nvf.homeManagerModules.default
      catppuccin.homeModules.catppuccin
    ];
    extraSpecialArgs = { inherit nix-secrets; };
    users.${primaryUser} = {
      imports = [
        ../../home/alberth
        ../../home/alberth/nixos.nix
        ../../home/alberth/nvf.nix
      ];
    };
  };
}
