# Generates a host age key at /etc/age/host-key on first activation.
# The host can use this key to self-decrypt ragenix secrets at boot
# without the YubiKey present.
#
# NOTE: on the very first deployment the key won't exist yet, so the
# YubiKey is still required that one time. After the public key has been
# added to nix-secrets and secrets have been rekeyed, all subsequent
# boots are fully automatic.
{ pkgs, lib, ... }:

let
  generateHostKeyScript = ''
    if [ ! -f /etc/age/host-key ]; then
      echo "Generating host age key..."
      mkdir -p /etc/age
      chmod 700 /etc/age
      ${pkgs.age}/bin/age-keygen -o /etc/age/host-key
      chmod 600 /etc/age/host-key
      ${lib.optionalString (!pkgs.stdenv.isDarwin) "chown root:root /etc/age/host-key"}
      echo "Host age public key (add this to nix-secrets/secrets.nix and rekey):"
      ${pkgs.age}/bin/age-keygen -y /etc/age/host-key
    fi
  '';
in
lib.mkMerge [
  (lib.mkIf pkgs.stdenv.isDarwin {
    # darwin's /activate script is a fixed, hardcoded list of named stages
    # (see CLAUDE.md "darwin activation scripts") — a custom
    # activationScripts.<name> key like the NixOS branch below uses is
    # silently never run. extraActivation is nix-darwin's real extension
    # point and runs early (2nd stage overall). ragenix's own darwin
    # decryption has no activationScripts hook at all — it's a separate
    # launchd.daemons.activate-agenix daemon (RunAtLoad, KeepAlive on
    # failure), loaded during the much-later `launchd` stage — so the host
    # key is guaranteed to exist before that daemon first runs.
    system.activationScripts.extraActivation.text = lib.mkAfter generateHostKeyScript;
  })
  (lib.mkIf (!pkgs.stdenv.isDarwin) {
    system.activationScripts.generateAgeHostKey = {
      text = generateHostKeyScript;
      deps = [ ];
    };

    # Ensure the host key exists before ragenix runs
    system.activationScripts.agenix.deps = lib.mkAfter [ "generateAgeHostKey" ];
  })
]
