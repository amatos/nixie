# Template for new nix-darwin hosts based on the codex layout.
#
# To provision a new darwin host:
#   1. cp -r hosts/darwin/template-darwin hosts/darwin/<hostname>
#   2. Set networking.hostName and networking.computerName below.
#   3. cp home/alberth/template-darwin.nix home/alberth/<hostname>.nix
#      and update the imports reference below.
#   4. Add a darwinConfigurations entry in flake.nix (copy the codex block).
#   5. If the host needs a keytab: add nixie.krb5.keytabFile and the
#      corresponding age-encrypted secret to nix-secrets.
{
  pkgs,
  ...
}:

let
  userDefs = import ../../../users.nix;
  primaryUser = userDefs.primaryUser;
in
{
  imports = [
    ../common-darwin.nix
  ];

  networking.hostName = "template-darwin";
  networking.computerName = "template-darwin";

  # Darwin-specific system packages
  environment.systemPackages = [ ];

  # nix-homebrew — manages the Homebrew installation itself.
  # Remove if this host does not use Homebrew.
  nix-homebrew = {
    enable = true;
    enableRosetta = true; # x86 bottles on Apple Silicon via Rosetta 2
    user = primaryUser;
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      cleanup = "uninstall";
    };
    brews = [
      "mas" # Mac App Store CLI
      "pinentry-mac" # GPG pinentry with macOS Keychain / Touch ID support
    ];
    casks = [
      # Add host-specific casks here
      "ghostty"
    ];
  };

  # Merge host home overlay on top of the base imported by common-darwin.nix.
  # Update this import when the host is renamed.
  home-manager.users.${primaryUser} = {
    imports = [ ../../../home/alberth/template-darwin.nix ];
  };
}
