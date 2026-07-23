{ nix-secrets, ... }:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  sops.secrets.cachix-authtoken = {
    sopsFile = "${nix-secrets}/fleet-secrets.yaml";
    key = "cachix-authtoken";
    owner = primaryUser;
    mode = "0400";
  };
}
