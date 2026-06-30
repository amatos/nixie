# Sets the Syncthing GUI user and password from a ragenix secret at runtime.
#
# The secret contains the plaintext password; Syncthing hashes it itself
# when it receives the value via its REST API. This keeps the password out of
# the Nix store entirely.
#
# A oneshot systemd service extracts the API key from Syncthing's config.xml,
# waits for the REST API to be ready, then PATCHes the GUI config with the
# desired user and password.
#
# Import this module on any host that runs services.syncthing.
#
# The service uses partOf so it restarts whenever syncthing restarts — this
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
  inherit (userDefs) primaryUser;
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

        CONFIG_XML="${stConfigDir}/config.xml"

        # Wait for syncthing to write its config (may not exist on first boot).
        until [ -f "$CONFIG_XML" ]; do sleep 1; done

        # Extract the API key from config.xml directly.
        # Using 'syncthing cli --home=...' to discover the key doesn't work on
        # NixOS: --home is a flag for 'syncthing serve', not 'syncthing cli'.
        # The CLI ignores it and falls back to its own default search path,
        # where no API key exists, so it fails before making any connection.
        APIKEY=$(${pkgs.gnugrep}/bin/grep -oP '(?<=<apikey>)[^<]+' "$CONFIG_XML")

        # Use HTTPS if syncthing has TLS certs in its config dir (placed there
        # by the certbot syncthingDeploy hook); fall back to HTTP otherwise.
        # --insecure: the cert is issued for the hostname, not for [::1], so
        # hostname verification fails — but the connection is local-only.
        if [ -f "${stConfigDir}/https-cert.pem" ]; then
          BASE_URL="https://[::1]:8384"
          TLS_FLAG="--insecure"
        else
          BASE_URL="http://[::1]:8384"
          TLS_FLAG=""
        fi

        # Wait for the Syncthing REST API to become available.
        until ${pkgs.curl}/bin/curl -sf $TLS_FLAG \
            -H "X-API-Key: $APIKEY" \
            "$BASE_URL/rest/noauth/health" > /dev/null 2>&1; do
          sleep 1
        done

        # Set the GUI user and password via the REST API.
        # Syncthing bcrypt-hashes the password on receipt — the plaintext never
        # leaves this host and is not stored anywhere in the Nix store.
        ${pkgs.curl}/bin/curl -sf $TLS_FLAG \
          -X PATCH \
          -H "X-API-Key: $APIKEY" \
          -H "Content-Type: application/json" \
          --data-raw "{\"user\":\"syncthing\",\"password\":\"$(cat /run/agenix/syncthing-gui-password)\"}" \
          "$BASE_URL/rest/config/gui"
      '';
    };
  };
}
