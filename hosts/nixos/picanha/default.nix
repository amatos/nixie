# Picanha host configuration.
#
# Status: stub — hardware-configuration.nix is a placeholder.
# Before deploying:
#   1. Boot the installer ISO, then replace hardware-configuration.nix with:
#        nixos-generate-config --show-hardware-config
#   2. Add a nixosConfigurations.picanha entry in flake.nix.
#   3. If a keytab is needed: set nixie.krb5.keytabFile and add the
#      age-encrypted secret to keytabs-matos-cc.
_:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  imports = [
    ./hardware-configuration.nix
    ../common-nixos.nix
  ];

  networking.hostName = "picanha";

  # Firewall — SSH (22) is already opened by common-nixos.nix.
  # Add host-specific ports here.
  networking.firewall.enable = true;

  # Host-specific home overlay — uncomment and create the file if needed.
  # The NixOS common overlay (home/alberth/nixos.nix) is already applied
  # via modules/nixos/home-manager.nix; only add this if extra settings
  # are required for this specific host.
  home-manager.users.${primaryUser} = {
    imports = [ ../../../home/alberth/picanha.nix ];
  };
}
