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
#   6. If host-specific home settings are needed, add alberth/<hostname>.nix
#      to the nixie-homes repo, commit and push it, then wire it in below.
{ nixie-homes, ... }:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
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
  # The NixOS common overlay (nixie-homes' homeModules.alberth-nixos) is
  # already applied via modules/nixos/home-manager.nix; only add this if
  # extra settings are required for this specific host. No dedicated
  # homeModules output exists for a not-yet-created host file — reference
  # it directly until one is added to nixie-homes' flake.nix.
  # home-manager.users.${primaryUser} = {
  #   imports = [ "${nixie-homes}/alberth/template-nixos.nix" ];
  # };
}
