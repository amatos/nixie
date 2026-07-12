# Installer ISO for the ephemeraltron template host.
#
# On boot this ISO:
#   1. Auto-detects the first available block device
#   2. Partitions it (GPT — 512 MiB ESP + root)
#   3. Formats with labels matching hardware-configuration.nix (ESP, nixos)
#   4. Installs from the pre-built system closure (no internet required)
#   5. Reboots into the installed system
#
# Build:  nix build .#ephemeraltron-iso
# Result: result/iso/ephemeraltron-installer.iso
{
  pkgs,
  modulesPath,
  ephemeraltronSystem,
  ...
}:

let
  installScript = pkgs.writeShellScript "ephemeraltron-autoinstall" ''
    set -euo pipefail

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║    ephemeraltron auto-installer          ║"
    echo "║    target: 10.0.6.66/22                 ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    # Give udev a moment to settle block device paths
    sleep 3

    # Find the first block device (excludes loop, rom, ram)
    DISK=$(${pkgs.util-linux}/bin/lsblk -dpno NAME,TYPE \
      | awk '$2=="disk"{print $1}' \
      | head -1)

    if [ -z "$DISK" ]; then
      echo "ERROR: no block device found. Dropping to emergency shell."
      exit 1
    fi

    echo "Installing to: $DISK"
    echo ""

    # NVMe disks use p1/p2 suffixes; everything else uses 1/2
    if echo "$DISK" | grep -q nvme; then
      PART_ESP="''${DISK}p1"
      PART_ROOT="''${DISK}p2"
    else
      PART_ESP="''${DISK}1"
      PART_ROOT="''${DISK}2"
    fi

    # Wipe and partition — GPT, 512 MiB EFI System Partition, rest for root
    echo "[1/4] Partitioning..."
    ${pkgs.parted}/bin/parted --script "$DISK" -- \
      mklabel gpt \
      mkpart ESP fat32 1MiB 513MiB \
      set 1 esp on \
      mkpart primary ext4 513MiB 100%

    # Allow kernel to re-read the partition table
    ${pkgs.util-linux}/bin/partprobe "$DISK"
    sleep 2

    # Format — labels must match hardware-configuration.nix
    echo "[2/4] Formatting..."
    ${pkgs.dosfstools}/bin/mkfs.fat -F 32 -n ESP  "$PART_ESP"
    ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L nixos -F   "$PART_ROOT"

    # Mount
    echo "[3/4] Mounting..."
    mount "$PART_ROOT" /mnt
    mkdir -p /mnt/boot
    mount "$PART_ESP" /mnt/boot

    # Install from the pre-built closure bundled in this ISO (no internet needed)
    echo "[4/4] Installing NixOS..."
    nixos-install \
      --system ${ephemeraltronSystem} \
      --no-root-passwd \
      --no-channel-copy \
      --root /mnt

    echo ""
    echo "Installation complete."
    echo "Rebooting in 5 seconds — remove the installer ISO now."
    sleep 5
    reboot
  '';
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  # Pull the pre-built ephemeraltron system closure into the ISO's Nix store.
  # nixos-install copies from here to /mnt — no network access needed.
  system.extraDependencies = [ ephemeraltronSystem ];

  # Additional partitioning and formatting tools for the install script
  environment.systemPackages = with pkgs; [
    parted
    e2fsprogs
    dosfstools
    util-linux
  ];

  # Run the installer automatically on first boot
  systemd.services.autoinstall = {
    description = "Auto-install NixOS (ephemeraltron)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "local-fs.target"
      "network.target"
    ];
    # Give the user a chance to see the boot console before the installer starts
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = installScript;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };

  isoImage.isoName = "ephemeraltron-installer.iso";

  # zstd is faster than xz and produces near-identical sizes for this workload
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  system.stateVersion = "26.05";
}
