# CI build target — never provisioned or switched to interactively; exists
# so the darwin side of the flake has a real build/eval target in CI.
{
  pkgs,
  nix-home-alberth,
  ...
}:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  imports = [
    ../common-darwin.nix
    ../../../modules/darwin/home-manager.nix
    ../../../modules/common/development-packages.nix
  ];

  networking.hostName = "darwintron";
  networking.computerName = "darwintron";

  # Darwin-specific system packages
  # nixd — Nix language server, for editor tooling (Zed, nvf).
  environment.systemPackages = [
    pkgs.nixd
  ];

  # Merge darwintron home overlay on top of the base imported by
  # modules/darwin/home-manager.nix
  home-manager.users.${primaryUser} = {
    imports = [ nix-home-alberth.homeModules.alberth-darwintron ];
  };
}
