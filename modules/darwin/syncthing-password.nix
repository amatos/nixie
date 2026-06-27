# Sets the Syncthing GUI user and password from a ragenix secret at runtime.
#
# On darwin, Syncthing is installed as a Homebrew cask (syncthing-app) and
# not managed by nix-darwin services, so credentials cannot be set
# declaratively. A launchd user agent runs at login, waits for the Syncthing
# API to become available, then applies the GUI user and password via
# `syncthing cli`. The password never touches the Nix store.
{
  pkgs,
  nix-secrets,
  ...
}:

let
  userDefs = import ../../users.nix;
  primaryUser = userDefs.primaryUser;
in
{
  age.secrets.syncthing-gui-password = {
    file = "${nix-secrets}/syncthing-gui-password.age";
    owner = primaryUser;
    mode = "0400";
  };

  launchd.user.agents.syncthing-gui-password = {
    serviceConfig = {
      Label = "com.nixie.syncthing-gui-password";
      ProgramArguments = [
        "${pkgs.writeShellScript "syncthing-set-gui-password" ''
          set -euo pipefail
          # Wait for the Syncthing API to become available before setting credentials.
          until ${pkgs.syncthing}/bin/syncthing cli config gui address get > /dev/null 2>&1; do
            sleep 1
          done
          ${pkgs.syncthing}/bin/syncthing cli config gui user set "syncthing"
          ${pkgs.syncthing}/bin/syncthing cli config gui password set \
            "$(cat /run/agenix/syncthing-gui-password)"
        ''}"
      ];
      RunAtLoad = true;
      KeepAlive = false;
      StandardOutPath = "/tmp/syncthing-gui-password.log";
      StandardErrorPath = "/tmp/syncthing-gui-password.log";
    };
  };
}
