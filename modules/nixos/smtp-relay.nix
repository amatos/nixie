# Postfix SMTP relay (smarthost) module.
# Configures Postfix to relay all outbound mail through an upstream SMTP server
# using SASL authentication and STARTTLS.
#
# The SASL credentials file must be a sops-encrypted Postfix passwd map in the format:
#   [smtp.fastmail.com]:587 user@example.com:app-password
#
# Uses texthash: lookup so no postmap run is required — the sops-nix-decrypted
# plain-text file is read directly by Postfix.
#
# Usage — in a host's default.nix:
#   nixie.smtpRelay.enable = true;
#
# Remember to also import modules/common/smtp-relay-secrets.nix so the
# sops-nix secret is deployed before Postfix starts.
{
  config,
  lib,
  ...
}:

# NixOS's postfix module leaves myhostname at its Postfix-compiled default
# (the bare system hostname, e.g. "huginn") unless networking.domain is set
# fleet-wide, which it isn't. myhostname is set to the LAN FQDN below,
# fixing myorigin and the SMTP HELO/EHLO greeting -- but that alone does
# NOT fix mail clients (e.g. mailutils' `mail`/`mailx`) that build their
# own From address directly from gethostname(), producing "user@huginn"
# (a syntactically complete address, just with a short-hostname domain).
# myorigin only rewrites addresses with no domain part at all, so it never
# touches this case, and upstream relays (Fastmail observed) reject it
# outright with "need fully-qualified address". smtp_generic_maps below
# rewrites it at the Postfix SMTP client, regardless of what the
# originating mail client constructed.

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
      default = config.sops.secrets.smtp-relay-sasl.path;
      defaultText = "config.sops.secrets.smtp-relay-sasl.path";
      description = ''
        Path to the sops-nix-decrypted Postfix SASL passwd map file.
        Defaults to the sops-nix-managed secret path. Uses texthash: lookup
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
        # Postfix restarting on credential changes is handled by
        # modules/common/smtp-relay-secrets.nix's sops.secrets.smtp-relay-sasl.restartUnits.
        # No explicit boot-ordering dependency is needed: sops-nix installs
        # secrets via the same activation-script phase NixOS itself uses,
        # which completes before services (re)start.

        # Generic table rewriting the bare hostname domain to the LAN FQDN
        # on outbound mail — see the module-level comment above. "@<host>"
        # as a generic(5) key matches any address in that domain regardless
        # of local-part. texthash: needs no postmap run, same as the SASL
        # password map below.
        #
        # Deliberately NOT under /etc/postfix/ — that path is a runtime
        # bind-mount from /var/lib/postfix/conf (NixOS's postfix module
        # manages it as a whole unit), so environment.etc can't inject an
        # individual extra file into it (mkdir collision at build time).
        # Same reason the SASL password map above references a /run/secrets
        # path rather than anything under /etc/postfix/.
        environment.etc."postfix-generic-map".text = ''
          @${config.networking.hostName} ${config.networking.hostName}.home.matos.cc
        '';

        services.postfix = {
          enable = true;

          settings.main = {
            # See the module-level comment above: fixes myorigin (used to
            # qualify unqualified local senders) and the HELO/EHLO greeting.
            myhostname = "${config.networking.hostName}.home.matos.cc";
            smtp_generic_maps = "texthash:/etc/postfix-generic-map";

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
