# Deploys the Tailscale auth key from nix-secrets.
# Decrypted to tmpfs at /run/secrets/tailscale-authkey — never written to disk.
# Used by services.tailscale.authKeyFile on NixOS.
# Darwin hosts use the Homebrew tailscale-app cask which manages its own auth.
{ nix-secrets, ... }:

{
  sops.secrets.tailscale-authkey = {
    sopsFile = "${nix-secrets}/fleet-secrets.yaml";
    key = "tailscale-authkey";
    owner = "root";
    mode = "0400";
  };
}
