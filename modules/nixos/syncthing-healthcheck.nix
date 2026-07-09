# Watchdog for a Syncthing failure mode observed on gammu and huginn: the
# main syncthing process stays alive (systemd reports the unit as
# active/running, sync itself over :22000 keeps working) but its GUI/REST
# API listener silently stops accepting connections — no crash, no log
# message, no unit restart. Because the unit never fails, systemd's
# `Restart=on-failure` never fires, and there's nothing to gate with unit
# ordering: syncthing-init.service and syncthing-gui-password.nix already
# declare correct After=/Requires=/PartOf= on syncthing.service (see CLAUDE.md
# Syncthing conventions) but that only proves the unit was active when they
# started, not that its API is still responding right now. A periodic timer
# polls the health endpoint directly and force-restarts syncthing.service
# when it stops responding.
#
# Targets loopback [::1] directly rather than reusing guiAddress, same
# pattern as syncthing-password.nix (safe regardless of what guiAddress is
# bound to — see that module and CLAUDE.md for why).
#
# Import this module on any host that runs services.syncthing.
{ config, pkgs, ... }:

let
  stConfigDir = config.services.syncthing.configDir;
in
{
  systemd.services.syncthing-healthcheck = {
    description = "Restart Syncthing if its GUI/API stops responding";
    after = [ "syncthing.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail

      if [ -f "${stConfigDir}/https-cert.pem" ]; then
        BASE_URL="https://[::1]:8384"
        TLS_FLAG="--insecure"
      else
        BASE_URL="http://[::1]:8384"
        TLS_FLAG=""
      fi

      if ${pkgs.curl}/bin/curl -sf --max-time 10 $TLS_FLAG \
          "$BASE_URL/rest/noauth/health" > /dev/null 2>&1; then
        exit 0
      fi

      echo "syncthing GUI/API unresponsive, restarting syncthing.service" >&2
      ${pkgs.systemd}/bin/systemctl restart syncthing.service
    '';
  };

  systemd.timers.syncthing-healthcheck = {
    description = "Periodic Syncthing GUI/API health check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      Unit = "syncthing-healthcheck.service";
    };
  };
}
