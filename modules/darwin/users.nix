# Shared nix-darwin module — configures users from the centralized roster.
# nix-darwin assumes users already exist on macOS; it only manages their
# nix-controlled properties. NixOS-only fields are stripped out.
{ lib, ... }:

let
  # Fields that are NixOS-only or custom metadata — not valid in nix-darwin.
  strippedFields = [ "isNormalUser" "extraGroups" "description" "email" "gpgSigningKey" ];

  # Top-level keys in users.nix that are metadata, not user entries.
  metaKeys = [ "primaryUser" ];

  userDefs = import ../../users.nix;

  # nix-darwin defaults users.users.<name>.home to null (unlike NixOS which
  # derives it from isNormalUser). The home-manager bridge reads that field to
  # set home.homeDirectory, so we must supply it explicitly here.
  toUserAttrs = name: cfg: (removeAttrs cfg strippedFields) // { home = "/Users/${name}"; };
in
{
  users.users = lib.mapAttrs toUserAttrs (removeAttrs userDefs metaKeys);
}
