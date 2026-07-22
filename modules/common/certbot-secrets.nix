# Deploys the LuaDNS API credentials for certbot from nix-secrets.
# Decrypted to tmpfs at /run/secrets/luadns-ini — never written to disk.
{ nix-secrets, ... }:

{
  sops.secrets.luadns-ini = {
    sopsFile = "${nix-secrets}/fleet-secrets.yaml";
    key = "luadns-ini";
    owner = "root";
    mode = "0400";
    # No restartUnits here: this module is shared by every host (darwin +
    # NixOS), but only porkchop actually runs dyndns-luadns.service — a
    # hardcoded restart target here would be wrong for everyone else.
    # certbot itself runs via a periodic timer/oneshot, not a persistent
    # daemon that needs restarting on credential rotation.
  };
}
