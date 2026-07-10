# Sirloin host configuration.
#
# Status: stub — hardware-configuration.nix is a placeholder.
# Before deploying:
#   1. Boot the installer ISO, then replace hardware-configuration.nix with:
#        nixos-generate-config --show-hardware-config
#   2. Add a nixosConfigurations.sirloin entry in flake.nix.
#   3. If a keytab is needed: set nixie.krb5.keytabFile and add the
#      age-encrypted secret to nix-keytabs-matos-cc.
_: {
  imports = [
    ./hardware-configuration.nix
    ../common-nixos.nix
  ];

  networking.hostName = "sirloin";

  # Firewall — SSH (22) is already opened by common-nixos.nix.
  # Add host-specific ports here.
  networking.firewall.enable = true;

  # Host-specific home overlay: add alberth/sirloin.nix to the nix-alberth-home
  # repo if needed, commit and push it, then run
  # `nix flake lock --update-input nix-alberth-home` here. nix-alberth-home's
  # alberth/nixos.nix auto-imports it when it exists — no manual wiring
  # required beyond updating the flake input.
}
