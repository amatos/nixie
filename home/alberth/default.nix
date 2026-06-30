{
  pkgs,
  nix-secrets,
  ...
}:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  imports = [
    ./atuin.nix
    ./chezmoi.nix
    ./devenv.nix
    ./starship.nix
    ./common/cachix.nix
    ./common/git.nix
    ./common/gpg.nix
    ./common/packages.nix
    ./common/shells.nix
    ./common/ssh.nix
    ./common/theming.nix
    ./common/tools.nix
  ];

  home.username = primaryUser;
  home.homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${primaryUser}" else "/home/${primaryUser}";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Man pages with pre-built cache for fast `man -k` lookups
  programs.man = {
    enable = true;
    generateCaches = false;
  };

  # XDG base directories — moves config, cache, and data out of ~
  xdg.enable = true;

  # age identity — symlinked to the canonical location so ragenix and age tools
  # find it without requiring an explicit -i flag (via the shell alias in shells.nix).
  home.file.".config/age/yubikey-identity.txt".source =
    "${nix-secrets}/age-yubikey-identity-9ca1fbf9.txt";

  # Environment variables applied to all shells
  home.sessionVariables = {
    ALTERNATE_EDITOR = "";
    EDITOR = "nvim";
    VISUAL = "zed -w";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    CLICOLOR = "1";
  };

  home.stateVersion = "26.05";
}
