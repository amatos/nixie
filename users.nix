# Centralized user definitions.
# Each entry is passed to users.users.<name> on every host.
# Add or remove users here; hosts import this via the shared module.
{
  # The primary interactive user — referenced by modules that need a username.
  primaryUser = "alberth";

  # Local admin account — NixOS hosts only; used for initial setup and emergency access.
  nixos = {
    isNormalUser = true;
    description = "NixOS Admin";
    extraGroups = [ "wheel" ];
  };

  alberth = {
    isNormalUser = true;
    description = "Alberth Matos";
    extraGroups = [ "wheel" ]; # wheel grants sudo
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILfxNl1S0Fvzh2aOAG6FuIwB96eqnUqY1nl2p2jSnTOD"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAif6Mv0L/8n9hrhwM9KJdU4zzWmAcUz/Y/NgfRwOFOZDBl+YJjRcg8BH71PP8D559HSq73x259+Txps66bli5M="
    ];
    email = "alberth@matos.cc";
    gpgSigningKey = "F41BDBF6171A3BB4";
  };
}
