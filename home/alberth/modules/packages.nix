{ pkgs, lib, ... }:

{
  home.packages =
    with pkgs;
    [
      # Tools
      htop # interactive process viewer
      imagemagick # image manipulation
      openssl # cryptographic toolkit
      pandoc # universal document converter
      ragenix # ragenix CLI — rekey secrets, add recipients
      ripgrep # fast recursive search (rg)

      # Fonts — those without nixpkgs equivalents stay as homebrew casks
      anonymousPro
      font-awesome
      hack-font
      inconsolata
      jetbrains-mono
      liberation_ttf
      nerd-fonts.dejavu-sans-mono
      nerd-fonts.hack
      nerd-fonts.inconsolata-go
      nerd-fonts.jetbrains-mono
    ]
    # Linux-only packages — macOS ships Heimdal Kerberos in /usr/bin
    ++ lib.optionals pkgs.stdenv.isLinux (
      with pkgs;
      [
        krb5 # kinit / klist / kdestroy for MATOS.CC realm
      ]
    )
    # x86_64-Linux-only packages (no aarch64-linux or Darwin build in nixpkgs)
    ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 (
      with pkgs;
      [
        slack
        zoom-us
        spotify
      ]
    );

  home.sessionPath = [
    "$HOME/.cargo/bin"
    "$HOME/.pnpm-packages/bin"
    "$HOME/.pnpm-packages"
    "$HOME/.npm-packages/bin"
    "$HOME/bin"
    "$HOME/.composer/vendor/bin"
    "$HOME/.local/share/bin"
    "$HOME/.local/share/src/conductly/bin"
    "$HOME/.local/share/src/conductly/utils"
  ];
}
