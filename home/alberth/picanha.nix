# Gammu-specific home-manager settings for alberth.
{ pkgs, ... }:

{
  # Gammu-only packages
  home.packages = [
    pkgs.krb5 # kinit / klist / kdestroy for MATOS.CC realm
  ];
}
