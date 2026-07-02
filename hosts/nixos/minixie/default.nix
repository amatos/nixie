# Minimal, generic NixOS bootstrap host for nixos-anywhere deploys.
#
# Deploy a fresh machine with:
#   nixos-anywhere --flake .#minixie root@<target-ip>
#
# This installs a bare NixOS + ragenix system with no identity baked in.
# Replace the placeholder SSH key below before deploying. Once the machine
# is reachable, replace this stub entirely with a real nixie host config
# (see hosts/nixos/template-nixos/default.nix) — minixie only exists to get
# a box from "freshly booted installer/rescue image" to "reachable over SSH
# with disko-partitioned disks", not to be a long-lived configuration.
#
# Optional: generate a hardware report via nixos-facter as part of the deploy:
#   nixos-anywhere --flake .#minixie \
#     --generate-hardware-config nixos-facter facter.json \
#     root@<target-ip>
# Skip --generate-hardware-config to reuse the existing facter.json, or if
# you don't need hardware-specific detection (disk-config.nix falls back to
# /dev/sda when facter.json is absent).
{
  modulesPath,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk-config.nix
  ];

  boot.loader.systemd-boot.enable = true;
  networking.hostName = "minixie";
  services.openssh.enable = true;

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.ragenix
    pkgs.vim
  ];

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "$6$oPxzAGGXHvqnKk9x$Y.baXB0nbtkJq252JfjK.bcQv0FhW2GzzCONu8/LNfVj266GnVKdevCBXvCOegIMtoRRwbhfbmRQIzjfifhEE/";
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      # Replace with your own key before deploying.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILfxNl1S0Fvzh2aOAG6FuIwB96eqnUqY1nl2p2jSnTOD"
    ];
    hashedPassword = "$6$oPxzAGGXHvqnKk9x$Y.baXB0nbtkJq252JfjK.bcQv0FhW2GzzCONu8/LNfVj266GnVKdevCBXvCOegIMtoRRwbhfbmRQIzjfifhEE/";
  };

  system.stateVersion = "26.05";
}
