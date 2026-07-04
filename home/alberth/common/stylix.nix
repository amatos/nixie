{ pkgs, lib, ... }:

{
  # Stylix and home-manager are pinned independently; the version-check is
  # a coarse string comparison that flags any mismatch even when the actual
  # APIs used are compatible. Disable it — real incompatibilities show up
  # as build errors, not as this banner.
  stylix.enableReleaseChecks = false;

  # Stylix's home module unconditionally adds nixpkgs.overlays entries
  # (nixos-icons, gtksourceview). With useGlobalPkgs = true, home-manager
  # loads the nixpkgs-disabled module whose nixpkgs.overlays option defaults
  # to null — any non-null value (even []) triggers the warning. Force back
  # to null so the warning check (cfg.overlays != null) is false. The
  # overlays are unused anyway since HM uses the system pkgs instance.
  nixpkgs.overlays = lib.mkForce null;

  # Prevent any stylix target from writing dconf keys during home-manager
  # activation. dconf writes require a live D-Bus session; SSH-based switches
  # on headless and KDE hosts have none. All hosts in this fleet are
  # non-GNOME, so these settings are unused regardless.
  dconf.settings = lib.mkForce { };

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

      # Disabled — GTK/GNOME theming writes dconf keys during home-manager
      # activation, which requires a running D-Bus session. Headless NixOS
      # hosts and darwin have no D-Bus session over SSH, causing failure.
      # gammu runs KDE (not GNOME), so these settings are unused on all hosts.
      gtk.enable = false;
      gnome.enable = false;
      eog.enable = false;
    };
  };
}
