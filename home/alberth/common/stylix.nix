{ pkgs, ... }:

{
  stylix = {
    enable = true;

    # Dracula from the community base16-schemes collection — same palette
    # previously embedded manually in theming.nix, now centralised here.
    base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
    polarity = "dark";

    # 1×1 Dracula-background pixel — satisfies the required image option.
    # Used for wallpaper on Linux desktops; not applied on darwin or headless
    # NixOS hosts. Colors are driven by base16Scheme above, not this image.
    image =
      pkgs.runCommand "dracula-bg.png"
        {
          nativeBuildInputs = [ pkgs.imagemagick ];
        }
        ''
          convert -size 1x1 xc:#282a36 "PNG:$out"
        '';

    fonts.monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };

    targets = {
      # Keep the custom powerline prompt in starship.nix — the named-palette
      # segment colours are incompatible with stylix's generated format.
      starship.enable = false;

      # Keep tmuxPlugins.dracula (tools.nix) — provides richer status-bar
      # segments than stylix's generated tmux theme.
      tmux.enable = false;

      # nvf manages neovim theming internally (nvf.nix: theme.name = "dracula").
      nvf.enable = false;
      vim.enable = false;
    };
  };
}
