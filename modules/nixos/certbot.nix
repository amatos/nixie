# Certbot with the LuaDNS DNS-01 challenge plugin.
# Credentials are read from /run/agenix/luadns-ini (deployed by ragenix).
#
# certbot-dns-luadns is not in nixpkgs; packaged locally in pkgs/python/.
# It uses dns-lexicon (which IS in nixpkgs) for the LuaDNS API calls.
#
# Usage — in a host's default.nix:
#   nixie.certbot.domains = [ [ "example.com" "www.example.com" ] ];  # one cert, two SANs
#   nixie.certbot.domains = [ "example.com" ];                        # single-domain shorthand
#   nixie.certbot.syncthingDeploy = true;  # copy renewed cert to syncthing + restart
#   nixie.certbot.postfixDeploy = true;   # copy renewed cert to /etc/postfix/ssl/ + reload postfix
#   nixie.certbot.chronyDeploy = true;    # copy renewed cert to /var/lib/chrony-tls/ + restart chronyd
{
  config,
  pkgs,
  lib,
  ...
}:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
  cfg = config.nixie.certbot;

  # certbot-dns-luadns is not in nixpkgs — packaged locally
  certbotDnsLuadns = pkgs.python3.pkgs.callPackage ../../pkgs/python/certbot-dns-luadns.nix {
    certbot = pkgs.python3.pkgs.certbot;
    acme = pkgs.python3.pkgs.acme;
    dns-lexicon = pkgs.python3.pkgs.dns-lexicon;
  };

  # Python environment with certbot + LuaDNS plugin; provides bin/certbot
  certbotWithLuadns = pkgs.python3.withPackages (ps: [
    ps.certbot
    certbotDnsLuadns
  ]);

  syncthingConfigDir = "/home/${primaryUser}/.config/syncthing";
  postfixSslDir = "/var/lib/postfix-tls";
  chronyTlsDir = "/var/lib/chrony-tls";
  openldapTlsDir = "/var/lib/openldap-tls";

  # Deploy hooks — run only when a certificate is actually renewed.
  # $RENEWED_LINEAGE is set by certbot to the live cert dir (e.g. /etc/letsencrypt/live/example.com).

  syncthingDeployHook = pkgs.writeShellScript "certbot-syncthing-deploy" ''
    set -euo pipefail
    mkdir -p "${syncthingConfigDir}"
    install -o ${primaryUser} -m 644 "$RENEWED_LINEAGE/fullchain.pem" "${syncthingConfigDir}/https-cert.pem"
    install -o ${primaryUser} -m 600 "$RENEWED_LINEAGE/privkey.pem"   "${syncthingConfigDir}/https-key.pem"
    systemctl restart syncthing.service
  '';

  # Installs cert+key into /etc/postfix/ssl/ with root:postfix 640 so smtpd can read the key.
  # Reloads (not restarts) postfix so in-flight connections are not dropped.
  postfixDeployHook = pkgs.writeShellScript "certbot-postfix-deploy" ''
    set -euo pipefail
    install -o root -g postfix -m 640 "$RENEWED_LINEAGE/fullchain.pem" "${postfixSslDir}/fullchain.pem"
    install -o root -g postfix -m 640 "$RENEWED_LINEAGE/privkey.pem"   "${postfixSslDir}/privkey.pem"
    systemctl reload postfix.service
  '';

  # Installs cert+key into /var/lib/chrony-tls/ with root:chrony 640 so chronyd can read the key.
  # Restarts (not reloads) chronyd — chrony re-reads cert files only on startup.
  chronyDeployHook = pkgs.writeShellScript "certbot-chrony-deploy" ''
    set -euo pipefail
    install -o root -g chrony -m 640 "$RENEWED_LINEAGE/fullchain.pem" "${chronyTlsDir}/fullchain.pem"
    install -o root -g chrony -m 640 "$RENEWED_LINEAGE/privkey.pem"   "${chronyTlsDir}/privkey.pem"
    systemctl restart chronyd.service
  '';

  # Installs cert+key into /var/lib/openldap-tls/ with root:openldap 640 so slapd can read the
  # key.  Restarts openldap — slapd re-reads TLS files only on startup.
  openldapDeployHook = pkgs.writeShellScript "certbot-openldap-deploy" ''
    set -euo pipefail
    install -o root -g openldap -m 640 "$RENEWED_LINEAGE/fullchain.pem" "${openldapTlsDir}/fullchain.pem"
    install -o root -g openldap -m 640 "$RENEWED_LINEAGE/privkey.pem"   "${openldapTlsDir}/privkey.pem"
    systemctl restart openldap.service
  '';

  # Collect whichever deploy hooks are enabled; certbot accepts multiple --deploy-hook flags.
  deployHookFlags = lib.concatStringsSep " " (
    lib.optional cfg.syncthingDeploy "--deploy-hook ${syncthingDeployHook}"
    ++ lib.optional cfg.postfixDeploy "--deploy-hook ${postfixDeployHook}"
    ++ lib.optional cfg.chronyDeploy "--deploy-hook ${chronyDeployHook}"
    ++ lib.optional cfg.ldapDeploy "--deploy-hook ${openldapDeployHook}"
  );

  # Each entry in cfg.domains is a list of domain names for a single cert.
  # Multiple entries produce multiple certs; multiple names within one entry become SANs.
  certbotCmd = domains: ''
    ${certbotWithLuadns}/bin/certbot certonly \
      --dns-luadns \
      --dns-luadns-credentials /run/agenix/luadns-ini \
      --email ${cfg.email} \
      --agree-tos \
      --non-interactive \
      --keep-until-expiring \
      --expand \
      ${deployHookFlags} \
      ${lib.concatMapStringsSep " " (d: "-d '${d}'") domains}
  '';
in
{
  options.nixie.certbot = {
    enable = lib.mkEnableOption "certbot with LuaDNS DNS-01 plugin";

    email = lib.mkOption {
      type = lib.types.str;
      default = userDefs.${userDefs.primaryUser}.email;
      description = "Email address for Let's Encrypt registration and expiry notices.";
    };

    domains = lib.mkOption {
      type = lib.types.listOf (
        lib.types.coercedTo lib.types.str lib.toList (lib.types.listOf lib.types.str)
      );
      default = [ ];
      example = [
        [
          "example.com"
          "www.example.com"
        ]
        [ "other.example.com" ]
      ];
      description = ''
        Certificates to issue. Each entry is a list of domain names that will be
        combined into a single certificate as SANs. A bare string is also accepted
        and treated as a single-domain certificate.
      '';
    };

    syncthingDeploy = lib.mkEnableOption "copy renewed cert to syncthing https-cert/key and restart syncthing.service";

    postfixDeploy = lib.mkEnableOption "copy renewed cert to /etc/postfix/ssl/ (root:postfix 640) and reload postfix.service";

    chronyDeploy = lib.mkEnableOption "copy renewed cert to /var/lib/chrony-tls/ (root:chrony 640) and restart chronyd.service";

    ldapDeploy = lib.mkEnableOption "copy renewed cert to /var/lib/openldap-tls/ (root:openldap 640) and restart openldap.service";
  };

  config = lib.mkIf cfg.enable {
    # Ensure certbot's working directories exist before the service starts.
    # ProtectSystem = "strict" bind-mounts ReadWritePaths into the namespace,
    # which fails with ENOENT if the directories don't exist yet (first run).
    systemd.tmpfiles.rules = [
      "d /etc/letsencrypt      0755 root root    -"
      "d /var/lib/letsencrypt  0755 root root    -"
      "d /var/log/letsencrypt  0755 root root    -"
    ]
    ++ lib.optionals cfg.postfixDeploy [
      # root:postfix 0750 — outside the Postfix chroot bind-mount tree (/etc/postfix →
      # /var/lib/postfix/conf) to avoid systemd namespace setup failures with ProtectSystem=strict
      "d /var/lib/postfix-tls  0750 root postfix -"
    ]
    ++ lib.optionals cfg.chronyDeploy [
      # root:chrony 0750 — holds the NTS server cert+key; group-readable by chronyd
      "d /var/lib/chrony-tls   0750 root chrony   -"
    ]
    ++ lib.optionals cfg.ldapDeploy [
      # root:openldap 0750 — holds the LDAPS cert+key; group-readable by slapd
      "d /var/lib/openldap-tls 0750 root openldap -"
    ];

    environment.systemPackages = [ certbotWithLuadns ];

    systemd.services.certbot = {
      description = "Certbot certificate renewal (LuaDNS)";
      after = [
        "network-online.target"
        "agenix.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "certbot-run" (
          lib.concatMapStringsSep "\n" certbotCmd cfg.domains
        );
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          "/etc/letsencrypt"
          "/var/lib/letsencrypt"
          "/var/log/letsencrypt"
        ]
        ++ lib.optionals cfg.syncthingDeploy [ syncthingConfigDir ]
        ++ lib.optionals cfg.postfixDeploy [ postfixSslDir ]
        ++ lib.optionals cfg.chronyDeploy [ chronyTlsDir ]
        ++ lib.optionals cfg.ldapDeploy [ openldapTlsDir ];
      };
    };

    systemd.timers.certbot = {
      description = "Certbot renewal timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };
}
