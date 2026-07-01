# Deploys the UniFi (UDM) local API read-only token used by the LuaDNS
# dyndns2 client to poll the gateway's current WAN IP.
# Decrypted to tmpfs at /run/agenix/unifi-api-key — never written to disk.
#
# The secret file must contain only the raw API key (no key=value wrapper,
# no trailing config syntax) — see UniFi Network > Settings > Control Plane
# > Integrations to generate a read-only token.
#
# The LuaDNS credentials themselves are NOT duplicated here — the dyndns2
# updater reuses the existing luadns-ini secret from certbot-secrets.nix
# (same LuaDNS account, same email+token pair).
#
# After adding this file to nix-secrets, run:
#   ragenix --rekey
# to encrypt it for all configured recipients (host keys + YubiKey).
{ nix-secrets, ... }:

{
  age.secrets.unifi-api-key = {
    file = "${nix-secrets}/unifi-api-key.age";
    owner = "root";
    mode = "0400";
    # path intentionally omitted — defaults to /run/agenix/unifi-api-key
  };
}
