{ nix-secrets, ... }:

let
  userDefs = import ../../users.nix;
  primaryUser = userDefs.primaryUser;
in
{
  age.secrets.cachix-authtoken = {
    file = "${nix-secrets}/cachix-authtoken.age";
    owner = primaryUser;
    mode = "0400";
  };
}
