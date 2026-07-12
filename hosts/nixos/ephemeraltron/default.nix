# Minimal NixOS host — exists solely as a CI build target (see ci.yml's
# build-ephemeraltron job), never provisioned or switched to interactively.
# This config intentionally omits ragenix, home-manager, certbot, and
# Tailscale, since none of that is needed just to build the closure. It also
# carries no networking, users, SSH, or sudo config — nothing here is ever
# booted or logged into.
_:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "ephemeraltron";

  # EFI bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Timezone and locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Set when this template was defined — do not change.
  system.stateVersion = "26.05";
}
