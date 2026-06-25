# chezmoi — dotfile manager.
# https://chezmoi.io
#
# Installs chezmoi and pre-configures it to use amatos/dotfiles as the source
# repo. Run `chezmoi init --apply` on a new machine to clone and apply.
{ ... }:

{
  programs.chezmoi = {
    enable = true;
    settings = {
      sourceURL = "https://github.com/amatos/dotfiles";
    };
  };
}
