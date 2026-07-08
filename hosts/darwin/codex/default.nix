{
  pkgs,
  lib,
  keytabs-matos-cc,
  homebrew-autoupdate,
  nixie-homes,
  ...
}:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  imports = [
    ../common-darwin.nix
    ../../../modules/darwin/certbot.nix
    ./homebrew.nix
    ../../../modules/darwin/syncthing-password.nix
    ../../../modules/common/certbot-secrets.nix
  ];

  networking.hostName = "codex";
  networking.computerName = "codex";

  # Darwin-specific system packages
  environment.systemPackages = [ pkgs.dockutil ];

  # Dedicated APFS volume backing OrbStack's container data (Docker images,
  # volumes, Linux VMs) — see nixie-homes' alberth/codex.nix for the Group
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
    enableRosetta = true; # x86 bottles on Apple Silicon via Rosetta 2
    user = primaryUser;
    autoMigrate = true; # adopt an existing /opt/homebrew install
    # Third-party taps must be declared here as nix inputs so nix-homebrew
    # can symlink them into /opt/homebrew/Library/Taps/ from the nix store.
    # Using `brew tap` at activation time fails because nix-homebrew owns
    # and write-protects that directory tree.
    taps = {
      "homebrew/homebrew-autoupdate" = homebrew-autoupdate;
    };
  };

  # Merge codex home overlay on top of the base imported by common-darwin.nix
  home-manager.users.${primaryUser} = {
    imports = [ nixie-homes.homeModules.alberth-codex ];
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

  nixie.krb5.keytabFile = "${keytabs-matos-cc}/keytab-codex.age";
}
