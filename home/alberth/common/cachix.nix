{ lib, config, ... }:

{
  # Write ~/.config/cachix/cachix.dhall from the ragenix secret on every activation.
  # Idempotent — safe to run repeatedly; updates automatically if the token rotates.
  home.activation.cachixConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    secret="/run/agenix/cachix-authtoken"
    cachix_cfg="${config.xdg.configHome}/cachix/cachix.dhall"

    if [ -f "$secret" ]; then
      token=$(cat "$secret")
      mkdir -p "$(dirname "$cachix_cfg")"
      printf '{ authToken = "%s" }\n' "$token" > "$cachix_cfg"
      chmod 600 "$cachix_cfg"
    fi
  '';
}
