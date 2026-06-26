# Workaround for a ragenix/systemd-tmpfiles ordering issue on NixOS.
#
# During `nixos-rebuild switch`, systemd-tmpfiles runs as part of the
# activation sequence and creates /run/agenix as a plain directory.
# The subsequent agenixInstall activation script then fails with
# "ln: /run/agenix: cannot overwrite directory" because `ln -s` cannot
# replace a directory with a symlink.
#
# Fix: run a script between tmpfiles and agenixInstall that removes
# /run/agenix if it is a directory rather than a symlink.
{ lib, ... }:

{
  system.activationScripts.agenixDirFix = {
    text = ''
      if [ -d /run/agenix ] && [ ! -L /run/agenix ]; then
        rm -rf /run/agenix
      fi
    '';
    deps = [ ];
  };

  # Ensure our cleanup runs before agenixInstall attempts the symlink.
  system.activationScripts.agenixInstall.deps = lib.mkAfter [ "agenixDirFix" ];
}
