# ragenix access-control file.
# Each key maps a secret file (relative to this directory) to the list of
# age public keys that can decrypt it.  Add secrets here, then run:
#   nix run github:yaxitech/ragenix -- -e secrets/<name>.age
let
  # YubiKey identity — matches identityPaths in nix-config
  alberth = "age1yubikey1qtpg5lwewq75p68ru0n909uzkqddkhym2mkwp37h2fwkkgfdem05ssa4m6y";
  codex   = "age1rx38js86awlvzvm99x8qhnhd42cn9ytcudgqzm44u9qk9g79kqhs9jktky";
  gammu   = "age1c2cmluquave5rmzequv7tea7c8zvt37yuml57vcd9qvvlla98qvsww99w0";

  users   = [ alberth ];
  systems = [ codex gammu ];
  allKeys = users ++ systems;
in
{
  # "example.age".publicKeys = allKeys;

  # GitHub secrets — source files live in nix-secrets
  "github-ratelimit.age".publicKeys = allKeys;
  "github-ssh-key.age".publicKeys = allKeys;

  # Certbot / LuaDNS
  "luadns.ini.age".publicKeys = allKeys;
}
