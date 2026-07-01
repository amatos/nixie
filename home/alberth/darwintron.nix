# Darwintron-specific home-manager settings for alberth.
# darwin/default.nix (imported below) provides GPG agent (pinentry-mac)
# and Ghostty terminal config shared by all darwin hosts.
_:

{
  imports = [
    ./darwin
  ];
}
