# Deploys the LuaDNS API credentials for certbot from nix-secrets.
# Decrypted to tmpfs at /run/agenix/luadns-ini — never written to disk.
#
# NOTE: do NOT set a `path` pointing inside /run/agenix/. Doing so causes
# agenix to run `mkdir -p /run/agenix` to create the parent directory,
# which prevents agenix from replacing /run/agenix with its generation symlink.
{ nix-secrets, ... }:

{
  age.secrets.luadns-ini = {
    file = "${nix-secrets}/luadns.ini.age";
    owner = "root";
    mode = "0400";
    # path intentionally omitted — defaults to /run/agenix/luadns-ini
  };
}
