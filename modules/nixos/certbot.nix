# Certbot with the LuaDNS DNS-01 challenge plugin.
# Credentials are read from /run/agenix/luadns.ini (deployed by ragenix).
#
# certbot-dns-luadns is not in nixpkgs; packaged locally in pkgs/python/.
# It uses dns-lexicon (which IS in nixpkgs) for the LuaDNS API calls.
#
# Usage — in a host's default.nix:
#   nixie.certbot.domains = [ "example.com" "*.example.com" ];
#   nixie.certbot.syncthingDeploy = true;  # copy renewed cert to syncthing + restart
{ config, pkgs, lib, ... }:

let
  userDefs    = import ../../users.nix;
  primaryUser = userDefs.primaryUser;
  cfg         = config.nixie.certbot;

  # certbot-dns-luadns is not in nixpkgs — packaged locally
  certbotDnsLuadns = pkgs.python3.pkgs.callPackage ../../pkgs/python/certbot-dns-luadns.nix {
    certbot    = pkgs.python3.pkgs.certbot;
    acme       = pkgs.python3.pkgs.acme;
    dns-lexicon = pkgs.python3.pkgs.dns-lexicon;
  };

  # Python environment with certbot + LuaDNS plugin; provides bin/certbot
  certbotWithLuadns = pkgs.python3.withPackages (ps: [ ps.certbot certbotDnsLuadns ]);

  syncthingConfigDir = "/home/${primaryUser}/.config/syncthing";

  # Runs only when a certificate is actually renewed (certbot --deploy-hook semantics).
  # $RENEWED_LINEAGE is set by certbot to the live cert dir (e.g. /etc/letsencrypt/live/example.com).
  syncthingDeployHook = pkgs.writeShellScript "certbot-syncthing-deploy" ''
    set -euo pipefail
    mkdir -p "${syncthingConfigDir}"
    install -o ${primaryUser} -m 644 "$RENEWED_LINEAGE/fullchain.pem" "${syncthingConfigDir}/https-cert.pem"
    install -o ${primaryUser} -m 600 "$RENEWED_LINEAGE/privkey.pem"   "${syncthingConfigDir}/https-key.pem"
    systemctl restart syncthing.service
  '';

  certbotCmd = domain: ''
    ${certbotWithLuadns}/bin/certbot certonly \
      --dns-luadns \
      --dns-luadns-credentials /run/agenix/luadns.ini \
      --email ${cfg.email} \
      --agree-tos \
      --non-interactive \
      --keep-until-expiring \
      ${lib.optionalString cfg.syncthingDeploy "--deploy-hook ${syncthingDeployHook}"} \
      -d '${domain}'
  '';
in
{
  options.nixie.certbot = {
    enable = lib.mkEnableOption "certbot with LuaDNS DNS-01 plugin";

    email = lib.mkOption {
      type    = lib.types.str;
      default = userDefs.${userDefs.primaryUser}.email;
      description = "Email address for Let's Encrypt registration and expiry notices.";
    };

    domains = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [];
      example     = [ "example.com" "*.example.com" ];
      description = "Domains to issue certificates for. Each entry becomes a -d argument.";
    };

    syncthingDeploy = lib.mkEnableOption "copy renewed cert to syncthing https-cert/key and restart syncthing.service";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ certbotWithLuadns ];

    systemd.services.certbot = {
      description = "Certbot certificate renewal (LuaDNS)";
      after       = [ "network-online.target" "agenix.service" ];
      wants       = [ "network-online.target" ];
      serviceConfig = {
        Type            = "oneshot";
        User            = "root";
        ExecStart       = pkgs.writeShellScript "certbot-run" (
          lib.concatMapStringsSep "\n" certbotCmd cfg.domains
        );
        PrivateTmp      = true;
        ProtectSystem   = "strict";
        ReadWritePaths  = [ "/etc/letsencrypt" "/var/lib/letsencrypt" "/var/log/letsencrypt" ]
          ++ lib.optionals cfg.syncthingDeploy [ syncthingConfigDir ];
      };
    };

    systemd.timers.certbot = {
      description     = "Certbot renewal timer";
      wantedBy        = [ "timers.target" ];
      timerConfig = {
        OnCalendar         = "weekly";
        RandomizedDelaySec = "1h";
        Persistent         = true;
      };
    };
  };
}
