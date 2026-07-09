# Shared home-manager configuration for all NixOS hosts.
# Each host still imports a platform-specific overlay
# (nixie-homes' homeModules.alberth-nixos) via users.<primaryUser> — that
# module handles NixOS-only divergences (pinentry-tty, open alias, etc.).
{
  pkgs,
  nvf,
  qmd,
  nix-secrets,
  stylix,
  nixie-homes,
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
      qmd.homeModules.default
      stylix.homeModules.stylix
    ];
    extraSpecialArgs = { inherit nix-secrets; };
    users.${primaryUser} = {
      imports = [
        nixie-homes.homeModules.alberth
        nixie-homes.homeModules.alberth-nixos
        nixie-homes.homeModules.alberth-nvf
      ];
    };
  };
}
