# Configures codex as a Nix remote-build client, using gammu (a physical
# x86_64-linux host already in the fleet) as an x86_64-linux builder — so
# `nix build`/`nixos-rebuild build` for x86_64-linux hosts works from codex
# without "a builder for x86_64-linux couldn't be found".
#
# nix-darwin's own nix.buildMachines/nix.distributedBuilds (and the built-in
# nix.linux-builder VM) do NOT work here: Determinate Nix forces
# `nix.enable = false` on darwin, and nix-darwin's entire `nix.*` config
# block — including the code that writes /etc/nix/machines — is wrapped in
# `lib.mkIf config.nix.enable` (modules/nix/default.nix upstream). So those
# options silently evaluate to nothing, same class of gotcha as the
# `nix.settings.trusted-users` one documented in common-darwin.nix.
# `nix.linux-builder.enable` even asserts `config.nix.enable`, so it's not
# usable at all under Determinate.
#
# Workaround: write /etc/nix/machines directly via environment.etc, bypassing
# nix.buildMachines entirely. This works because `builders = @/etc/nix/machines`
# is already Determinate Nix's effective default (confirmed via
# `nix show-config` — no nix.custom.conf entry required), so the only missing
# piece was ever the file itself plus SSH access.
#
# Only codex imports this (not nhcodex/darwintron) — see
# modules/nixos/remote-build-server.nix (imported only by gammu) for the
# matching server-side half (the `remotebuild` user gammu trusts).
{
  nix-secrets,
  ...
}:

{
  sops.secrets.remote-build-ssh-key = {
    sopsFile = "${nix-secrets}/builder-codex-ssh-key.yaml";
    key = "builder-codex-ssh-key";
    path = "/etc/nix/remotebuild_ed25519";
    # The nix-daemon (and thus remote-build ssh connections) runs as root on
    # darwin, unlike the primaryUser-owned secrets elsewhere in this repo.
    owner = "root";
    mode = "0600";
  };

  # Format: see build-remote.pl / nix-darwin's linux-builder.nix — one line
  # per machine: "[ssh://][user@]host system(s) sshKey maxJobs speedFactor
  # supportedFeatures mandatoryFeatures [publicHostKey]". publicHostKey is
  # base64 of gammu's `ssh-ed25519 ...` host key (ssh-keyscan), the same
  # format nix-darwin's own linux-builder module uses for its local VM — it
  # lets Nix verify the host key itself without touching root's known_hosts.
  environment.etc."nix/machines".text = ''
    ssh-ng://remotebuild@gammu.ts.matos.cc x86_64-linux /etc/nix/remotebuild_ed25519 4 1 - - c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU93cEZYUjRQSFBwNHpQeVRNL255d3BNVTVhbWVQelcvY0RVTUljNWFmZkU=
  '';
}
