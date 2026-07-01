# Dynamic DNS updater for LuaDNS, using LuaDNS's own dyndns2-protocol
# endpoint (https://www.luadns.com/dyndns.html) rather than the full REST
# API — the same LuaDNS account/credentials already used by certbot's
# DNS-01 challenge (modules/common/certbot-secrets.nix), reused here.
#
# Every `interval`, a oneshot service:
#   1. reads the current WAN IP from the UniFi OS gateway's local API
#      (GET /proxy/network/api/s/default/stat/health, X-API-Key auth —
#      the read-only token from UniFi Network > Settings > Control Plane
#      > Integrations, deployed via modules/common/dyndns-luadns-secrets.nix)
#   2. compares it to the last IP recorded in /var/lib/dyndns-luadns/current-ip
#   3. if changed, calls LuaDNS's dyndns2 endpoint over HTTPS
#      (https://app.luadns.com/nic/update) to update the A record, using
#      the email+token pair from /run/agenix/luadns-ini
#
# The target hostname's A (and/or AAAA) record must already exist in LuaDNS
# before enabling this — the dyndns2 protocol updates existing records, it
# does not create them.
#
# Usage — in a host's default.nix:
#   nixie.dyndnsLuadns = {
#     enable = true;
#     hostname = "home.matos.cc";
#     gatewayHost = "unifi";   # UniFi OS console's local address
#   };
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.nixie.dyndnsLuadns;
  stateDir = "/var/lib/dyndns-luadns";

  runScript = pkgs.writeShellScript "dyndns-luadns-run" ''
    set -euo pipefail

    # LuaDNS credentials — reuse certbot's luadns-ini (same account/token).
    luadnsEmail=$(sed -n 's/^dns_luadns_email *= *//p' /run/agenix/luadns-ini | tr -d '[:space:]')
    luadnsToken=$(sed -n 's/^dns_luadns_token *= *//p' /run/agenix/luadns-ini | tr -d '[:space:]')
    if [ -z "$luadnsEmail" ] || [ -z "$luadnsToken" ]; then
      echo "dyndns-luadns: could not read dns_luadns_email/dns_luadns_token from /run/agenix/luadns-ini" >&2
      exit 1
    fi

    unifiApiKey=$(cat /run/agenix/unifi-api-key)

    # Query the UDM's local (legacy-path) controller API for the current WAN
    # IP. Authenticated with the UniFi Network read-only API key via
    # X-API-Key — no session cookie needed on UniFi OS consoles.
    # --insecure: the UDM's local HTTPS listener uses a self-signed cert on
    # the LAN; this is the standard way local tooling talks to it.
    health=$(curl -fsS --insecure \
      -H "X-API-Key: $unifiApiKey" \
      -H "Accept: application/json" \
      "https://${cfg.gatewayHost}/proxy/network/api/s/default/stat/health")

    wanIp=$(printf '%s' "$health" | ${pkgs.jq}/bin/jq -er '.data[] | select(.subsystem == "wan") | .wan_ip')
    if ! printf '%s' "$wanIp" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
      echo "dyndns-luadns: could not parse a WAN IPv4 address from gateway response: $health" >&2
      exit 1
    fi

    stateFile="${stateDir}/current-ip"
    lastIp=""
    if [ -f "$stateFile" ]; then
      lastIp=$(cat "$stateFile")
    fi

    if [ "$wanIp" = "$lastIp" ]; then
      echo "dyndns-luadns: WAN IP unchanged ($wanIp)"
      exit 0
    fi

    echo "dyndns-luadns: WAN IP changed (''${lastIp:-none} -> $wanIp), updating LuaDNS"

    # dyndns2 update — HTTPS only (LuaDNS does not support plain HTTP here).
    # No -f: dyndns2 servers report failures (badauth, abuse, 911, ...) as a
    # 200 response with a status body, not a non-2xx HTTP status.
    response=$(curl -sS \
      -u "$luadnsEmail:$luadnsToken" \
      "https://app.luadns.com/nic/update?hostname=${cfg.hostname}&myip=$wanIp")

    case "$response" in
      good\ *|nochg\ *)
        printf '%s' "$wanIp" > "$stateFile"
        echo "dyndns-luadns: LuaDNS update result: $response"
        ;;
      *)
        echo "dyndns-luadns: LuaDNS update FAILED: $response" >&2
        exit 1
        ;;
    esac
  '';
in
{
  options.nixie.dyndnsLuadns = {
    enable = lib.mkEnableOption "LuaDNS dyndns2 client for the WAN IP behind a UniFi gateway";

    hostname = lib.mkOption {
      type = lib.types.str;
      example = "home.matos.cc";
      description = ''
        LuaDNS-hosted hostname to keep pointed at the current WAN IP. The A
        record must already exist in the zone — dyndns2 updates it, it does
        not create it.
      '';
    };

    gatewayHost = lib.mkOption {
      type = lib.types.str;
      default = "unifi";
      description = ''
        Address of the UniFi OS console (UDM/UDM-Pro/UDR/UDM-SE) to query
        for the current WAN IP, reachable from this host.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = ''
        How often to check the WAN IP for changes. See
        {command}`man 7 systemd.time` for the format.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 root root -"
    ];

    systemd.services.dyndns-luadns = {
      description = "LuaDNS dyndns2 update for ${cfg.hostname}";
      after = [
        "network-online.target"
        "agenix.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = runScript;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ stateDir ];
      };
    };

    systemd.timers.dyndns-luadns = {
      description = "LuaDNS dyndns2 update timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitInactiveSec = cfg.interval;
        Persistent = true;
      };
    };
  };
}
