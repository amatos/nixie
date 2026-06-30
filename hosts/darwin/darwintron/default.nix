_:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  imports = [
    ../common-darwin.nix
  ];

  networking.hostName = "darwintron";
  networking.computerName = "darwintron";

  # Merge darwintron home overlay on top of the base imported by common-darwin.nix
  home-manager.users.${primaryUser} = {
    imports = [ ../../../home/alberth/darwintron.nix ];
  };
}
