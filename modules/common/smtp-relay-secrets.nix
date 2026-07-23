# Deploys the Postfix SASL credentials for the SMTP relay from nix-secrets.
# Decrypted to tmpfs at /run/secrets/smtp-relay-sasl — never written to disk.
#
# The secret is a single "smtp-relay-sasl" key in smtp-relay-sasl.yaml,
# a Postfix passwd map line in the format:
#   [smtp.fastmail.com]:587 user@example.com:app-password
#
# After changing this file in nix-secrets, run:
#   sops updatekeys smtp-relay-sasl.yaml
# to re-encrypt it for all configured recipients (host keys + YubiKey).
{ nix-secrets, ... }:

{
  sops.secrets.smtp-relay-sasl = {
    sopsFile = "${nix-secrets}/smtp-relay-sasl.yaml";
    key = "smtp-relay-sasl";
    owner = "root";
    mode = "0400";
    restartUnits = [ "postfix.service" ];
  };
}
