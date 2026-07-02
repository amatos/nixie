_:

{
  # eza (modern ls replacement)
  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    icons = "auto";
    git = true;
    extraOptions = [ "--header" ];
  };

  # fzf with shell integrations
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  # bat — cat clone with syntax highlighting
  # Dracula is bundled with bat itself; do not enable catppuccin.bat.
  programs.bat = {
    enable = true;
    config = {
      theme = "Dracula";
      italic-text = "always";
    };
  };

  # btop — resource monitor
  programs.btop.enable = true;

  # tealdeer (tldr client) with auto-update
  programs.tealdeer = {
    enable = true;
    settings.updates.auto_update = true;
  };

  # zoxide — smarter cd, aliased to cd across all shells
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    options = [ "--cmd cd" ];
  };

  # direnv with nix-direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  # Nushell
  programs.nushell.enable = true;
}
