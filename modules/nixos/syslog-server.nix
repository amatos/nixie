# Centralized syslog receiver — accepts UDP/TCP syslog from fleet hosts and
# writes one log file per sending host, keyed by the sender's own configured
# syslog hostname. Stage 7a of the porkchop service realignment
# (ARCHITECTURE.md §10). Import only on porkchop; firewall access is the
# consuming host's responsibility (see hosts/nixos/porkchop/default.nix).
{
  config,
  lib,
  ...
}:

let
  cfg = config.nixie.syslogServer;
in
{
  options.nixie.syslogServer = {
    enable = lib.mkEnableOption "Centralized syslog receiver (rsyslog, UDP+TCP 514)";
  };

  config = lib.mkIf cfg.enable {
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
  };
}
