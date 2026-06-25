# Centralized user definitions.
# Each entry is passed to users.users.<name> on every host.
# Add or remove users here; hosts import this via the shared module.
{
  # The primary interactive user — referenced by modules that need a username.
  primaryUser = "alberth";

  alberth = {
    isNormalUser = true;
    description = "Alberth Matos";
    extraGroups = [ "wheel" ]; # wheel grants sudo
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILfxNl1S0Fvzh2aOAG6FuIwB96eqnUqY1nl2p2jSnTOD"
    ];
    email         = "alberth@matos.cc";
    gpgSigningKey = "F41BDBF6171A3BB4";
  };
}
