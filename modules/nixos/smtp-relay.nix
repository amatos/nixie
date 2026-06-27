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
  };

  config = lib.mkIf cfg.enable {
    # Postfix must start after agenix has decrypted the SASL credentials.
    systemd.services.postfix = {
      after = [ "agenix.service" ];
      wants = [ "agenix.service" ];
    };

    services.postfix = {
      enable = true;

      settings.main = {
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
  };
}
