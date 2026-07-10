# Shared home-manager configuration for all NixOS hosts.
# Each host still imports a platform-specific overlay
# (nix-alberth-home's homeModules.alberth-nixos) via users.<primaryUser> — that
# module handles NixOS-only divergences (pinentry-tty, open alias, etc.).
{
  pkgs,
  nvf,
  qmd,
  nix-secrets,
  stylix,
  direnv-instant,
  nix-alberth-home,
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
      direnv-instant.homeModules.direnv-instant
    ];
    extraSpecialArgs = { inherit nix-secrets; };
    users.${primaryUser} = {
      imports = [
        nix-alberth-home.homeModules.alberth
        nix-alberth-home.homeModules.alberth-nixos
        nix-alberth-home.homeModules.alberth-nvf
      ];
    };
  };
}
