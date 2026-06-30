{ nix-secrets, ... }:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  age.secrets.cachix-authtoken = {
    file = "${nix-secrets}/cachix-authtoken.age";
    owner = primaryUser;
    mode = "0400";
  };
}
