# nhcodex — a lean test bed for future home-manager changes, with zero
# nix-alberth-home involvement. networking.hostName/computerName stay "codex"
# (only the flake attribute name and this host directory differ).
#
# Reuses common-darwin.nix directly, no duplication — that file no longer
# bakes in home-manager config (see modules/darwin/home-manager.nix, split
# out specifically so a host can opt out), so nhcodex simply doesn't import
# it. Homebrew (codex/homebrew.nix) is skipped too, since its autoupdate
# script is sourced from nix-alberth-home. Add home-manager.darwinModules.
# home-manager is already in this host's flake.nix module list — set
# home-manager.users.${primaryUser} here directly as you experiment.
{
  nix-keytabs-matos-cc,
  ...
}:

{
  imports = [
    ../common-darwin.nix
    ../../../modules/darwin/certbot.nix
    ../../../modules/darwin/syncthing-password.nix
    ../../../modules/common/certbot-secrets.nix
  ];

  networking.hostName = "codex";
  networking.computerName = "codex";

  nixie.certbot = {
    enable = true;
    domains = [
      [
        "codex.home.matos.cc"
        "codex.ts.matos.cc"
      ]
    ];
    syncthingDeploy = true; # copy renewed cert to syncthing and restart on renewal
  };

  nixie.krb5.keytabFile = "${nix-keytabs-matos-cc}/keytab-codex.age";
}
