# Configures ragenix to decrypt secrets using the host age key.
# The host key is generated on first activation by age-host-key.nix and
# is the only identity needed for automated decryption during activation.
#
# The YubiKey identity is intentionally NOT listed here — age initialises
# all identity files before attempting decryption, and the plugin binary
# is not on PATH during the activation environment.  The YubiKey is only
# needed interactively when running `ragenix` to create or rekey secrets,
# which uses the recipient public keys from secrets/secrets.nix directly.
{ ... }:

{
  age.identityPaths = [
    "/etc/age/host-key"
  ];
}
