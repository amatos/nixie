# Development-oriented packages — wired to hosts used for active development
# (gammu, codex), not deployed fleet-wide like modules/common/packages.nix.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    black
    cmake
    codex
    commitizen
    commitlint
    diff-so-fancy
    doxygen
    gemini-cli
    github-copilot-cli
    gnumake
    imagemagick
    inkscape # Vector graphics editor
    lazygit
    nmap
    pre-commit
    prettier
    pyenv
    pylint
    pyrefly
    rbenv
    shellcheck
    yaml-language-server
    yamllint
  ];
}
