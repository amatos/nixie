# Sirloin-specific home-manager settings for alberth.
{ pkgs, ... }:

{
  # Sirloin-only packages
  home.packages = [
    pkgs.krb5 # kinit / klist / kdestroy for MATOS.CC realm
  ];
}
