# Picanha-specific home-manager settings for alberth.
{ pkgs, ... }:

{
  # Picanha-only packages
  home.packages = [
    pkgs.krb5 # kinit / klist / kdestroy for MATOS.CC realm
  ];
}
