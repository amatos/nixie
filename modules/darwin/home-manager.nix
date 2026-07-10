# Home-manager base config for darwin hosts that use nix-alberth-home.
# Mirrors modules/nixos/home-manager.nix's role on the NixOS side. Not part
# of common-darwin.nix — split out specifically so a host can opt out of
# nix-alberth-home entirely (see hosts/darwin/nhcodex, a testbed host with no
# nix-alberth-home involvement) without duplicating anything.
#
# Hosts that want this import it alongside common-darwin.nix, then merge
# their own overlay via:
#   home-manager.users.${primaryUser} = { imports = [ nix-alberth-home.homeModules.alberth-<host> ]; };
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
        nix-alberth-home.homeModules.alberth-nvf
      ];
      # openssh_gssapi shadows pkgs.openssh (added to PATH by nix-darwin's
      # services.openssh) so the SSH client supports GSSAPIAuthentication.
      home.packages = [ pkgs.openssh_gssapi ];
    };
  };
}
