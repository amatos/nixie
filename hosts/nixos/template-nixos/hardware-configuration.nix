# Replace this file with the output of nixos-generate-config on the target
# machine after booting the installer ISO:
#
#   nixos-generate-config --show-hardware-config
#
# Copy the result here before running nixos-rebuild switch.
#
# The fileSystems."/" entry below is a placeholder only — just enough to
# satisfy NixOS's "fileSystems option does not specify your root file
# system" assertion so `nix flake check` can evaluate this template. It
# does not point at a real device and must be replaced along with the
# rest of this file before this host is ever built or deployed.
_: {
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
