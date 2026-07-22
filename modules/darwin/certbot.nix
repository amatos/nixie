# Certbot with the LuaDNS DNS-01 challenge plugin.
# Credentials are read from /run/secrets/luadns-ini (deployed by sops-nix).
#
# certbot-dns-luadns is not in nixpkgs; packaged locally in pkgs/python/.
# It uses dns-lexicon (which IS in nixpkgs) for the LuaDNS API calls.
#
# Usage — in a host's default.nix:
#   nixie.certbot.domains = [ [ "example.com" "www.example.com" ] ];  # one cert, two SANs
#   nixie.certbot.domains = [ "example.com" ];                        # single-domain shorthand
#   nixie.certbot.syncthingDeploy = true;  # copy renewed cert to syncthing + restart
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

  # Runs only when a certificate is actually renewed (certbot --deploy-hook semantics).
  # $RENEWED_LINEAGE is set by certbot to the live cert dir (e.g. /etc/letsencrypt/live/example.com).
  # Path contains a space ("Application Support") — use a shell variable throughout.
  syncthingDeployHook = pkgs.writeShellScript "certbot-syncthing-deploy" ''
    set -euo pipefail
    config_dir="/Users/${primaryUser}/Library/Application Support/Syncthing"
    mkdir -p "$config_dir"
    install -o ${primaryUser} -m 644 "$RENEWED_LINEAGE/fullchain.pem" "$config_dir/https-cert.pem"
    install -o ${primaryUser} -m 600 "$RENEWED_LINEAGE/privkey.pem"   "$config_dir/https-key.pem"
    # syncthing-app runs as a user LaunchAgent; killing it causes launchd to restart it
    pkill -u ${primaryUser} syncthing 2>/dev/null || true
  '';

  certbotScript = pkgs.writeShellScript "certbot-run" (
    lib.concatMapStringsSep "\n" (domains: ''
      ${certbotWithLuadns}/bin/certbot certonly \
        --dns-luadns \
        --dns-luadns-credentials ${config.sops.secrets.luadns-ini.path} \
        --email ${cfg.email} \
        --agree-tos \
        --non-interactive \
        --keep-until-expiring \
        --expand \
        ${lib.optionalString cfg.syncthingDeploy "--deploy-hook ${syncthingDeployHook}"} \
        ${lib.concatMapStringsSep " " (d: "-d '${d}'") domains}
    '') cfg.domains
  );
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

    syncthingDeploy = lib.mkEnableOption "copy renewed cert to syncthing https-cert/key and restart syncthing";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ certbotWithLuadns ];

    launchd.daemons.certbot = {
      script = "${certbotScript}";
      serviceConfig = {
        Label = "org.nixie.certbot";
        RunAtLoad = false;
        StartCalendarInterval = [
          {
            Weekday = 0;
            Hour = 3;
            Minute = 0;
          }
        ]; # weekly, Sunday 03:00
        StandardOutPath = "/var/log/certbot.log";
        StandardErrorPath = "/var/log/certbot.log";
      };
    };
  };
}
