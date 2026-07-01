# template-darwin — darwin host-specific home-manager settings.
# Copy to home/alberth/<hostname>.nix when provisioning a new darwin host.
#
# darwin/default.nix (imported below) provides: GPG agent (pinentry-mac),
# Ghostty terminal (enable, package = null, command = fish). Add only
# host-specific divergences here.
_:

{
  imports = [
    ./darwin
  ];

  # Add host-specific home settings here, e.g.:
  # programs.ssh.settings."host.example.com" = { User = "admin"; };
}
