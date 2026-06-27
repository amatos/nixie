# Deploys the Postfix SASL credentials for the SMTP relay from nix-secrets.
# Decrypted to tmpfs at /run/agenix/smtp-relay-sasl — never written to disk.
#
# The secret file must be a Postfix passwd map line in the format:
#   [smtp.fastmail.com]:587 user@example.com:app-password
#
# After adding this file to nix-secrets, run:
#   ragenix --rekey
# to encrypt it for all configured recipients (host keys + YubiKey).
{ nix-secrets, ... }:

{
  age.secrets.smtp-relay-sasl = {
    file = "${nix-secrets}/smtp-relay-sasl.age";
    owner = "root";
    mode = "0400";
    # path intentionally omitted — defaults to /run/agenix/smtp-relay-sasl
  };
}
