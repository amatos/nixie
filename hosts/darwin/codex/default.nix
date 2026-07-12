{
  pkgs,
  lib,
  nix-keytabs-matos-cc,
  homebrew-autoupdate,
  homebrew-cirruslabs-cli,
  homebrew-dracula-install,
  nix-home-alberth,
  ...
}:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  imports = [
    ../common-darwin.nix
    ../../../modules/darwin/home-manager.nix
    ../../../modules/darwin/certbot.nix
    ./homebrew.nix
    ../../../modules/darwin/syncthing-password.nix
    ../../../modules/common/certbot-secrets.nix
    ../../../modules/common/development-packages.nix
  ];

  networking.hostName = "codex";
  networking.computerName = "codex";

  # Darwin-specific system packages
  # dockutil — pins/manages Homebrew-cask GUI apps on the Dock.
  # nixd — Nix language server, for editor tooling (Zed, nvf).
  environment.systemPackages = [
    pkgs.dockutil
    pkgs.nixd
  ];

  # Dedicated APFS volume backing OrbStack's container data (Docker images,
  # volumes, Linux VMs) — see nix-home-alberth's alberth/codex.nix for the Group
  # Container symlink that points at it and the Docker daemon config. disk3 is codex's
  # internal APFS container; re-check with `diskutil apfs list` if the
  # physical disk layout ever changes.
  #
  # nix-darwin's /activate script is assembled from a fixed list of named
  # stages (see modules/system/activation-scripts.nix upstream) — arbitrary
  # custom activationScripts.<name> keys are silently never run. extraActivation
  # is the supported extension point and runs early, before homebrew/home-manager.
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    if ! diskutil info "ContainerData" >/dev/null 2>&1; then
      echo "creating ContainerData APFS volume..." >&2
      diskutil apfs addVolume disk3 APFS ContainerData
    fi
  '';

  # nix-homebrew — manages the Homebrew installation itself
  nix-homebrew = {
    enable = true;
    enableRosetta = false; # alternate x86 bottles on Apple Silicon via Rosetta 2
    user = primaryUser;
    autoMigrate = true; # adopt an existing /opt/homebrew install
    # Third-party taps must be declared here as nix inputs so nix-homebrew
    # can symlink them into /opt/homebrew/Library/Taps/ from the nix store.
    # Using `brew tap` at activation time fails because nix-homebrew owns
    # and write-protects that directory tree.
    taps = {
      "homebrew/homebrew-autoupdate" = homebrew-autoupdate;
      "cirruslabs/homebrew-cli" = homebrew-cirruslabs-cli;
      "dracula/homebrew-install" = homebrew-dracula-install;
    };
  };

  # Merge codex home overlay on top of the base imported by
  # modules/darwin/home-manager.nix
  home-manager.users.${primaryUser} = {
    imports = [ nix-home-alberth.homeModules.alberth-codex ];
  };

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
