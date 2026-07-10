{ nix-alberth-home, ... }:

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
    imports = [ nix-alberth-home.homeModules.alberth-darwintron ];
  };
}
