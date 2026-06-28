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
  pkgs,
  nix-secrets,
  ...
}:

let
  userDefs = import ../../users.nix;
  primaryUser = userDefs.primaryUser;
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
    # bindsTo (not requires): propagates restarts so this service re-runs every
    # time syncthing restarts, not just on first boot.
    bindsTo = [ "syncthing.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = primaryUser;
      # No RemainAfterExit — the service must be able to re-run after becoming inactive.
      ExecStart = pkgs.writeShellScript "syncthing-set-gui-password" ''
        set -euo pipefail
        # Wait for the Syncthing API to become available before setting credentials.
        until ${pkgs.syncthing}/bin/syncthing cli config gui address get > /dev/null 2>&1; do
          sleep 1
        done
        ${pkgs.syncthing}/bin/syncthing cli config gui user set "syncthing"
        ${pkgs.syncthing}/bin/syncthing cli config gui password set \
          "$(cat /run/agenix/syncthing-gui-password)"
      '';
    };
  };
}
