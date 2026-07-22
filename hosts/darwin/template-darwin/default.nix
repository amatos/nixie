# Template for new nix-darwin hosts based on the codex layout.
#
# To provision a new darwin host:
#   1. cp -r hosts/darwin/template-darwin hosts/darwin/<hostname>
#   2. Set networking.hostName and networking.computerName below.
#   3. In the nix-home-alberth repo: cp alberth/template-darwin.nix alberth/<hostname>.nix,
#      add a homeModules.alberth-<hostname> entry in its flake.nix, commit, and push.
#      Then update the imports reference below to
#      nix-home-alberth.homeModules.alberth-<hostname>.
#   4. Add a darwinConfigurations entry in flake.nix (copy the codex block).
#   5. If the host needs a keytab: add nixie.krb5.keytabFile and the
#      corresponding sops-encrypted binary keytab to nix-secrets.
{
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
  ];

  networking.hostName = "template-darwin";
  networking.computerName = "template-darwin";

  # Darwin-specific system packages
  environment.systemPackages = [ ];

  # nix-homebrew — manages the Homebrew installation itself.
  # Remove if this host does not use Homebrew.
  nix-homebrew = {
    enable = true;
    enableRosetta = false; # alternate x86 bottles on Apple Silicon via Rosetta 2
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

  # Merge host home overlay on top of the base imported by
  # modules/darwin/home-manager.nix. References the template file directly
  # (no dedicated homeModules.alberth-* output exists for it, since it's
  # meant to be copied, not imported as-is) — update this import when the
  # host is renamed, per step 3 above.
  home-manager.users.${primaryUser} = {
    imports = [ "${nix-home-alberth}/alberth/template-darwin.nix" ];
  };
}
