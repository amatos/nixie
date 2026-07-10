{ nix-home-alberth, ... }:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  imports = [
    ../common-darwin.nix
    ../../../modules/darwin/home-manager.nix
  ];

  networking.hostName = "darwintron";
  networking.computerName = "darwintron";

  # Merge darwintron home overlay on top of the base imported by common-darwin.nix
  home-manager.users.${primaryUser} = {
    imports = [ nix-home-alberth.homeModules.alberth-darwintron ];
  };
}
