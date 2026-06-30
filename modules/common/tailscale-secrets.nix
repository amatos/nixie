# Deploys the Tailscale auth key from nix-secrets.
# Decrypted to tmpfs at /run/agenix/tailscale-authkey — never written to disk.
# Used by services.tailscale.authKeyFile on NixOS.
# Darwin hosts use the Homebrew tailscale-app cask which manages its own auth.
{ nix-secrets, ... }:

{
  age.secrets.tailscale-authkey = {
    file = "${nix-secrets}/tailscale-authkey.age";
    owner = "root";
    mode = "0400";
  };
}
