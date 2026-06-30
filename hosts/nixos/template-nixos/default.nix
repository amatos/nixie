# Template for new NixOS hosts based on the gammu layout.
#
# To provision a new NixOS host:
#   1. cp -r hosts/nixos/template-nixos hosts/nixos/<hostname>
#   2. Replace hardware-configuration.nix with the output of:
#        nixos-generate-config --show-hardware-config
#      (run on the target machine after booting the installer ISO).
#   3. Set networking.hostName below.
#   4. Add a nixosConfigurations entry in flake.nix (copy the gammu block).
#   5. If the host needs a keytab: add nixie.krb5.keytabFile and the
#      corresponding age-encrypted secret to keytabs-matos-cc.
#   6. If host-specific home settings are needed, create
#      home/alberth/<hostname>.nix and wire it in below.
{ ... }:

let
  userDefs = import ../../../users.nix;
  primaryUser = userDefs.primaryUser;
in
{
  imports = [
    ./hardware-configuration.nix
    ../common-nixos.nix
  ];

  networking.hostName = "template-nixos";

  # Firewall — SSH (22) is already opened by common-nixos.nix.
  # Add host-specific ports here.
  networking.firewall.enable = true;

  # Host-specific home overlay — uncomment and create the file if needed.
  # The NixOS common overlay (home/alberth/nixos.nix) is already applied
  # via modules/nixos/home-manager.nix; only add this if extra settings
  # are required for this specific host.
  # home-manager.users.${primaryUser} = {
  #   imports = [ ../../../home/alberth/template-nixos.nix ];
  # };
}
