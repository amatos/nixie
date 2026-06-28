# Sets the Syncthing GUI user and password from a ragenix secret at runtime.
#
# The secret contains the plaintext password; Syncthing hashes it itself
# when it receives the value via its CLI. This keeps the password out of
# the Nix store entirely.
#
# A oneshot systemd service waits for the Syncthing API to be ready, then
# calls `syncthing cli config gui {user,password} set` with the secret contents.
# Import this module on any host that runs services.syncthing.
#
# The service uses BindsTo so it restarts whenever syncthing restarts — this
# is necessary because the NixOS Syncthing module re-applies declarative GUI
# settings on each start (which can clear the password), and RemainAfterExit
# would prevent the service from re-running to restore it.
{
  config,
  pkgs,
  nix-secrets,
  ...
}:

let
  userDefs = import ../../users.nix;
  primaryUser = userDefs.primaryUser;
  # The NixOS Syncthing service starts with --home pointing to this directory.
  # syncthing cli must use the same path to find the API key; without --home it
  # defaults to a different location and can't authenticate.
  stConfigDir = config.services.syncthing.configDir;
in
{
  age.secrets.syncthing-gui-password = {
    file = "${nix-secrets}/syncthing-gui-password.age";
    owner = primaryUser;
    mode = "0400";
  };

  systemd.services.syncthing-gui-password = {
    description = "Set Syncthing GUI user and password from ragenix secret";
    after = [
      "syncthing.service"
      "agenix.service"
    ];
    # partOf: propagates stop AND restart from syncthing.service to this unit,
    # so credentials are re-applied every time syncthing restarts (e.g. after
    # nixos-rebuild switch), not just on first boot.
    partOf = [ "syncthing.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = primaryUser;
      # No RemainAfterExit — the service must be able to re-run after becoming inactive.
      # Give the wait loop a hard ceiling so a non-starting syncthing can't block forever.
      TimeoutStartSec = "120";
      ExecStart = pkgs.writeShellScript "syncthing-set-gui-password" ''
        set -euo pipefail
        # --home must match the path the NixOS syncthing service uses so the CLI
        # can find the API key. Without it, syncthing cli looks in the wrong
        # directory, fails to authenticate, and never makes a network connection.
        # --gui-address overrides the wildcard [::]:8384 from config with the
        # IPv6 loopback so the CLI can actually connect.
        # https:// — Syncthing enables TLS when https-cert.pem/https-key.pem exist in
        # the config dir (placed there by the certbot syncthingDeploy hook).
        # syncthing cli skips TLS verification for local GUI connections by default.
        ST_CLI="${pkgs.syncthing}/bin/syncthing cli --home=${stConfigDir} --gui-address=https://[::1]:8384"
        # Wait for the Syncthing API to become available before setting credentials.
        # Each attempt is wrapped with timeout(1) so a hanging TCP connection attempt
        # doesn't block the loop indefinitely.
        until timeout 2 $ST_CLI config gui address get > /dev/null 2>&1; do
          sleep 1
        done
        $ST_CLI config gui user set "syncthing"
        $ST_CLI config gui password set "$(cat /run/agenix/syncthing-gui-password)"
      '';
    };
  };
}
