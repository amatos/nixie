# Centralized syslog receiver — accepts UDP/TCP syslog from fleet hosts and
# writes one log file per sending host, keyed by the sender's own configured
# syslog hostname. Stage 7a of the porkchop service realignment
# (ARCHITECTURE.md §10). Import only on porkchop; firewall access is the
# consuming host's responsibility (see hosts/nixos/porkchop/default.nix).
{
  config,
  lib,
  nix-secrets,
  ...
}:

let
  cfg = config.nixie.syslogServer;
in
{
  options.nixie.syslogServer = {
    enable = lib.mkEnableOption "Centralized syslog receiver (rsyslog, UDP+TCP 514)";

    grafana.enable = lib.mkEnableOption ''
      Grafana + Loki log review UI on top of the syslog receiver (Stage 7b).
      Independently toggleable from the receiver itself so either half can
      be validated/rolled back on its own.
    '';
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.rsyslogd = {
        enable = true;
        # This host is a dedicated remote-log receiver, not a general local
        # syslog daemon — skip the default local file layout (dhcpd/mail/
        # warn/messages) and only keep the remote-logging rule below.
        defaultConfig = "";
        extraConfig = ''
          module(load="imudp")
          input(type="imudp" port="514")
          module(load="imtcp")
          input(type="imtcp" port="514")

          template(name="RemoteLogs" type="string" string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")

          if $fromhost-ip != '127.0.0.1' then {
            action(type="omfile" dynaFile="RemoteLogs" dirCreateMode="0750" createDirs="on")
            stop
          }
        '';
      };

      systemd.tmpfiles.rules = [ "d /var/log/remote 0750 root root -" ];
    })

    (lib.mkIf cfg.grafana.enable {
      # NixOS 26.05's Grafana module requires an explicit secret_key with no
      # default anymore (the old default was a shared, publicly-known
      # value). Referenced via Grafana's own $__file{} provider syntax so
      # the plaintext never appears in the Nix store.
      age.secrets.grafanaSecretKey = {
        file = "${nix-secrets}/grafana-secret-key.age";
        owner = "grafana";
        mode = "0400";
      };

      # Grafana must start after agenix has decrypted the secret key.
      systemd.services.grafana = {
        after = [ "agenix.service" ];
        wants = [ "agenix.service" ];
      };

      # Minimal single-node Loki — filesystem storage, no object store,
      # in-memory ring (no clustering). Fine for one host's worth of logs.
      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;
          server.http_listen_port = 3100;
          common = {
            path_prefix = "/var/lib/loki";
            storage.filesystem = {
              chunks_directory = "/var/lib/loki/chunks";
              rules_directory = "/var/lib/loki/rules";
            };
            replication_factor = 1;
            ring.kvstore.store = "inmemory";
          };
          schema_config.configs = [
            {
              from = "2024-01-01";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };
      };

      # Grafana bound to all interfaces — access is restricted at the
      # firewall level (Tailscale-only by default; see
      # hosts/nixos/porkchop/default.nix for whether a LAN rule was added).
      services.grafana = {
        enable = true;
        settings.server = {
          http_addr = "0.0.0.0";
          http_port = 3000;
        };
        settings.security.secret_key = "$__file{${config.age.secrets.grafanaSecretKey.path}}";
        provision.datasources.settings.datasources = [
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:3100";
            isDefault = true;
          }
        ];
      };
    })
  ];
}
