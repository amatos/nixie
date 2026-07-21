# Postfix SMTP relay (smarthost) module.
# Configures Postfix to relay all outbound mail through an upstream SMTP server
# using SASL authentication and STARTTLS.
#
# The SASL credentials file must be an age-encrypted Postfix passwd map in the format:
#   [smtp.fastmail.com]:587 user@example.com:app-password
#
# Uses texthash: lookup so no postmap run is required — the ragenix-decrypted
# plain-text file is read directly by Postfix.
#
# Usage — in a host's default.nix:
#   nixie.smtpRelay.enable = true;
#
# Remember to also import modules/common/smtp-relay-secrets.nix so the
# ragenix secret is deployed before Postfix starts.
{
  config,
  lib,
  ...
}:

# NixOS's postfix module leaves myhostname at its Postfix-compiled default
# (the bare system hostname, e.g. "huginn") unless networking.domain is set
# fleet-wide, which it isn't. myorigin defaults to $myhostname, so any
# locally-originated mail with no explicit envelope sender (e.g. a plain
# `mail`/`mailx` invocation with no -r) gets qualified as
# "user@huginn" instead of "user@huginn.home.matos.cc" -- which upstream
# relays can reject outright. Setting myhostname to the LAN FQDN here fixes
# both myorigin and the SMTP HELO/EHLO greeting in one place.

let
  cfg = config.nixie.smtpRelay;
  relayTarget = "[${cfg.relayHost}]:${toString cfg.relayPort}";
in
{
  options.nixie.smtpRelay = {
    enable = lib.mkEnableOption "Postfix SMTP relay (smarthost)";

    relayHost = lib.mkOption {
      type = lib.types.str;
      default = "smtp.fastmail.com";
      description = "Upstream SMTP smarthost hostname.";
    };

    relayPort = lib.mkOption {
      type = lib.types.port;
      default = 587;
      description = "Upstream SMTP smarthost port (submission).";
    };

    myNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "127.0.0.0/8"
        "[::1]/128"
      ];
      example = [
        "127.0.0.0/8"
        "[::1]/128"
        "10.0.4.0/22"
      ];
      description = ''
        Networks Postfix will relay mail for without requiring authentication.
        Always include loopback ranges. Add your LAN subnet and/or Tailscale
        range as needed.
      '';
    };

    saslSecretPath = lib.mkOption {
      type = lib.types.str;
      default = config.age.secrets.smtp-relay-sasl.path;
      defaultText = "config.age.secrets.smtp-relay-sasl.path";
      description = ''
        Path to the age-decrypted Postfix SASL passwd map file.
        Defaults to the ragenix-managed secret path. Uses texthash: lookup
        so no postmap run is required.
      '';
    };

    smtps = {
      enable = lib.mkEnableOption "SMTPS listener on port 465 (implicit TLS)";

      certDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/postfix-tls";
        description = ''
          Directory containing fullchain.pem and privkey.pem for the smtpd TLS listener.
          Must be readable by the postfix group. Intentionally outside /etc/postfix/ to
          avoid the Postfix chroot bind-mount (/etc/postfix → /var/lib/postfix/conf)
          causing systemd namespace failures with ProtectSystem=strict.
          Use nixie.certbot.postfixDeploy = true to deploy renewed certs here automatically.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # Postfix must start after agenix has decrypted the SASL credentials.
        systemd.services.postfix = {
          after = [ "agenix.service" ];
          wants = [ "agenix.service" ];
        };

        services.postfix = {
          enable = true;

          settings.main = {
            # See the module-level comment above: fixes myorigin (used to
            # qualify unqualified local senders) and the HELO/EHLO greeting.
            myhostname = "${config.networking.hostName}.home.matos.cc";

            # Listen on all interfaces so LAN / Tailscale hosts can relay.
            # Access is controlled by mynetworks below — not by interface binding.
            inet_interfaces = "all";
            inet_protocols = "all";

            # Networks Postfix will relay for without authentication
            mynetworks = cfg.myNetworks;

            # Relay all mail through the smarthost
            relayhost = [ relayTarget ];

            # Disable local mail delivery — this host is relay-only
            mydestination = "";
            local_transport = "error:local delivery disabled";

            # SASL authentication to the upstream smarthost.
            # texthash: reads the plain-text file directly — no postmap needed.
            smtp_sasl_auth_enable = true;
            smtp_sasl_password_maps = "texthash:${cfg.saslSecretPath}";
            smtp_sasl_security_options = "noanonymous";
            # nixpkgs builds Postfix with --with-cyrus-sasl by default
            smtp_sasl_type = "cyrus";

            # Require STARTTLS to the upstream relay
            smtp_tls_security_level = "encrypt";
            smtp_tls_loglevel = "1";
          };
        };
      }

      (lib.mkIf cfg.smtps.enable {
        # The NixOS Postfix module references /var/lib/postfix/conf/ssl (its chroot TLS path)
        # when smtpd TLS is configured. That directory is created by the postfix service at
        # runtime, but systemd's ProtectSystem=strict namespace setup for certbot.service
        # encounters the path during mount tree traversal before postfix has created it.
        # Pre-creating it via tmpfiles ensures it exists at namespace setup time.
        systemd.tmpfiles.rules = [ "d /var/lib/postfix/conf/ssl 0755 root root -" ];

        services.postfix = {
          # smtpd TLS — inbound connections from relay clients
          settings.main = {
            smtpd_tls_cert_file = "${cfg.smtps.certDir}/fullchain.pem";
            smtpd_tls_key_file = "${cfg.smtps.certDir}/privkey.pem";
            # "may" — offer TLS but don't require it on port 25; smtps wrapper enforces TLS implicitly
            smtpd_tls_security_level = "may";
            smtpd_tls_loglevel = "1";
          };

          # Enable the smtps (port 465) service in master.cf.
          # smtpd_tls_wrappermode=yes means the connection is TLS from the first byte (no STARTTLS).
          settings.master.smtps = {
            type = "inet";
            private = false;
            command = "smtpd";
            args = [
              "-o"
              "smtpd_tls_wrappermode=yes"
            ];
          };
        };
      })
    ]
  );
}
