# Deploys the Tailscale auth key from nix-secrets.
# Decrypted to tmpfs at /run/agenix/tailscale-authkey — never written to disk.
# Used by services.tailscale.authKeyFile on both NixOS and darwin.
{ nix-secrets, ... }:

{
  age.secrets.tailscale-authkey = {
    file = "${nix-secrets}/tailscale-authkey.age";
    owner = "root";
    mode = "0400";
  };
}
