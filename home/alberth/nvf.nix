# Neovim configuration via nvf.
# See https://github.com/notashelf/nvf for available options.
{ ... }:

{
  programs.nvf = {
    enable = true;

    settings.vim = {
      viAlias = true;
      vimAlias = true;

      # UI
      options = {
        number = true;
        relativenumber = false;
        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;
        wrap = false;
        scrolloff = 8;
        signcolumn = "yes";
        colorcolumn = "80";
      };

      theme = {
        enable = true;
        name = "dracula";
        # style = "mocha";
        transparent = true;
      };

      # Syntax / Treesitter
      treesitter = {
        enable = true;
      };

      # LSP
      lsp = {
        enable = true;
      };

      # Language support
      languages = {
        enableTreesitter = true;
        nix.enable = true;
        bash.enable = true;
        markdown.enable = true;
        fish.enable = true;
        python.enable = true;
        ts.enable = true;
        rust.enable = true;
      };

      # Completion
      autocomplete.nvim-cmp = {
        enable = true;
      };

      # Statusline
      statusline.lualine = {
        enable = true;
      };

      # File tree
      filetree.nvimTree = {
        enable = false;
      };

      # Telescope
      telescope = {
        enable = true;
      };

      # Git signs in the gutter
      git = {
        enable = true;
        gitsigns.enable = true;
      };
    };
  };
}
