_:

{
  # Catppuccin — global flavor and accent; autoEnable = false so we opt in per-tool.
  # bat uses a custom auto light/dark config — do not enable catppuccin.bat.
  # neovim is handled inside nvf.nix with its own catppuccin-mocha setup — do not enable catppuccin.nvim.
  catppuccin = {
    flavor = "macchiato";
    accent = "blue";
    autoEnable = false;
  };

  catppuccin.btop.enable = true;
  catppuccin.eza.enable = true;
  catppuccin.fish.enable = true;
  catppuccin.fzf.enable = true;
  catppuccin.starship.enable = true;
  catppuccin.zsh-syntax-highlighting.enable = true;
}
