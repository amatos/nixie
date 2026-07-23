# Deploys the UniFi (UDM) local API read-only token used by the LuaDNS
# dyndns2 client to poll the gateway's current WAN IP.
# Decrypted to tmpfs at /run/secrets/unifi-api-key — never written to disk.
#
# The secret file must contain only the raw API key (no key=value wrapper,
# no trailing config syntax) — see UniFi Network > Settings > Control Plane
# > Integrations to generate a read-only token.
#
# The LuaDNS credentials themselves are NOT duplicated here — the dyndns2
# updater reuses the existing luadns-ini secret from certbot-secrets.nix
# (same LuaDNS account, same email+token pair).
{ nix-secrets, ... }:

{
  sops.secrets.unifi-api-key = {
    sopsFile = "${nix-secrets}/fleet-secrets.yaml";
    key = "unifi-api-key";
    owner = "root";
    mode = "0400";
    restartUnits = [ "dyndns-luadns.service" ];
  };
}
