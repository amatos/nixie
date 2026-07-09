# Common packages installed on every host (NixOS and nix-darwin).
{ lib, pkgs, ... }:

let
  userDefs = import ../../users.nix;
  inherit (userDefs) primaryUser;
in
{
  # Allow unfree packages fleet-wide (slack, spotify, zoom-us, discord, etc.)
  nixpkgs.config.allowUnfree = true;

  # Register every shell nixie makes available as a permissible login shell.
  # On NixOS, programs.zsh.enable/programs.fish.enable already add themselves
  # here automatically (and programs.bash.enable defaults to true fleet-wide),
  # so this is a no-op there beyond nushell. On darwin, none of
  # programs.zsh/fish/bash add themselves to environment.shells — it's a
  # separate, unset option there — so without this, /etc/shells stays at
  # Apple's stock list (its own /bin/bash, /bin/zsh, ...), and the nix-store
  # fish that users.users.${primaryUser}.shell actually points to on darwin
  # is missing from it entirely. environment.shells has the identical type on
  # both platforms (listOf (either shellPackage path)), so one list covers
  # both.
  environment.shells = with pkgs; [
    bashInteractive
    zsh
    fish
    nushell
  ];

  # Binary caches — amatos.cachix.org for devenv and personal builds.
  # trusted-users: wheel-group members are trusted so that flake inputs
  # that declare extra substituters via nixConfig (nix-community, zed,
  # garnix, etc.) are actually used rather than silently ignored.
  nix.settings = {
    substituters = [ "https://amatos.cachix.org" ];
    trusted-public-keys = [ "amatos.cachix.org-1:f8dGcsYmNVdex+prgb03Pu5yCIDkzrB8dp2lmpBfNT4=" ];
    trusted-users = [
      "root"
      primaryUser
      "@wheel" # Linux (NixOS)
      "@staff" # macOS — admin users are in 'admin', not 'wheel'
    ];
  };

  environment.systemPackages =
    with pkgs;
    [
      age # age encryption
      age-plugin-yubikey
      bat
      btop
      cachix # Nix binary cache hosting — push and use build artifacts
      chezmoi
      cowsay
      curl
      direnv
      dos2unix
      eza
      fastfetch
      fortune
      fzf
      git
      gnupg
      htop
      httpie
      jq
      lsd
      nh # Nix helper — nicer `nixos-rebuild` / `darwin-rebuild` / `home-manager` UX
      pstree
      python3
      rage # Rust implementation of age
      ruby
      sesh
      starship
      tealdeer
      tmux
      uv
      wget
      zoxide
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      dockutil
      duti
      mas
    ]
    # ghostty.terminfo: Linux only — on darwin the Homebrew cask installs it automatically
    # pciutils (lspci): Linux only — PCI enumeration is not a darwin concept
    ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.ghostty.terminfo
      pkgs.pciutils
    ];
}
