# Deploys the LuaDNS API credentials for certbot from nix-secrets.
# Decrypted to tmpfs (/run/agenix/) — never written to disk.
{ nix-secrets, ... }:

{
  age.secrets.luadns-ini = {
    file = "${nix-secrets}/luadns.ini.age";
    path = "/run/agenix/luadns.ini";
    owner = "root";
    mode = "0400";
  };
}
