# Accepts remote Nix builds from codex, working around the fact that
# nix-darwin's own nix.buildMachines/nix.linux-builder are no-ops under
# Determinate Nix on darwin (see hosts/darwin/remote-build-client.nix for the
# full explanation). codex connects here over Tailscale as the unprivileged
# `remotebuild` user below.
#
# Import this module only on the host acting as the x86_64-linux builder
# (currently gammu).
{
  pkgs,
  ...
}:

{
  users.users.remotebuild = {
    isSystemUser = true;
    group = "remotebuild";
    # bash, not nologin: nix's build-remote ssh's in to run `nix-store
    # --serve` non-interactively, which needs a real shell to exec.
    # No password — SSH key only.
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      # Public half of the key deployed to codex by
      # hosts/darwin/remote-build-client.nix. Not secret — only the private
      # key (nix-secrets/builder/codex-ssh-key.age) needs to stay encrypted.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBkG/f5sq8p55ORgVKU3c1Fi/awnKj1vD7bqZHCdnpAe remotebuild@codex"
    ];
  };
  users.groups.remotebuild = { };

  # Must be able to submit builds without being sandboxed as untrusted
  # (nix-darwin's own linux-builder module requires the same for its
  # dedicated `builder` user).
  nix.settings.trusted-users = [ "remotebuild" ];
}
