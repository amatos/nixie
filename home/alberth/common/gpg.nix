{ pkgs, lib, ... }:

let
  userDefs = import ../../../users.nix;
  user = userDefs.${userDefs.primaryUser};
in
{
  programs.gpg.enable = true;

  # Import GPG public key on first activation.
  # Tries WKD (domain-hosted) first; falls back to keys.openpgp.org.
  # Skipped if the key is already in the keyring (idempotent).
  home.activation.importGpgKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _gpgBin="${pkgs.gnupg}/bin/gpg"
    _key="${user.gpgSigningKey}"
    _email="${user.email}"

    if ! "$_gpgBin" --list-keys "$_key" > /dev/null 2>&1; then
      echo "GPG: importing key $_key for $_email..."
      "$_gpgBin" --auto-key-locate wkd --locate-key "$_email" 2>/dev/null \
        || "$_gpgBin" --keyserver hkps://keys.openpgp.org --recv-keys "$_key" \
        || echo "GPG: warning — could not import key $_key (no network?)"
    fi

    # Ensure ultimate trust is set (safe to run every time)
    echo "$_key:6:" | "$_gpgBin" --import-ownertrust 2>/dev/null || true
  '';
}
