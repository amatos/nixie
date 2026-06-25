# Shared NixOS module — applies the centralized user roster to every host.
# Custom metadata fields (e.g. gpgSigningKey) are stripped before being
# passed to users.users, which only accepts known NixOS options.
{ lib, ... }:

let
  # Fields defined in users.nix that are NOT valid users.users options.
  # Add to this list whenever you introduce new custom metadata.
  customFields = [ "email" "gpgSigningKey" ];

  # Top-level keys in users.nix that are metadata, not user entries.
  metaKeys = [ "primaryUser" ];

  userDefs = import ../../users.nix;

  toUserAttrs = _name: cfg: removeAttrs cfg customFields;
in
{
  users.users = lib.mapAttrs toUserAttrs (removeAttrs userDefs metaKeys);
}
