{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common-nixos.nix
  ];

  networking.hostName = "nixostron";

  # Headless VM — no display server or GUI
  services.xserver.enable = false;

  # VirtIO disk support in the initrd — required to find /dev/vda at boot
  boot.initrd.availableKernelModules = [
    "virtio_blk"
    "virtio_pci"
    "virtio_scsi"
  ];
}
