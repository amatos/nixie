# chezmoi — dotfile manager.
# https://chezmoi.io
#
# programs.chezmoi is not available in home-manager 26.05; installed via
# home.packages instead.  On a new machine, initialise with:
#   chezmoi init --apply amatos/dotfiles
{ pkgs, ... }:

{
  home.packages = [ pkgs.chezmoi ];

  # Minimal global config — sets the GitHub username so `chezmoi init` can
  # infer the source repo without arguments.
  xdg.configFile."chezmoi/chezmoi.toml".text = ''
    [data]
      githubUsername = "amatos"
  '';
}
