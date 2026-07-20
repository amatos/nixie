# Development-oriented packages — wired to hosts used for active development
# (gammu, codex), not deployed fleet-wide like modules/common/packages.nix.
{ pkgs, ... }:

let
  # Python 3.13 changed argparse's "invalid choice" error message to quote
  # each choice individually (CPython gh-130750); commitizen 4.13.9's
  # test_invalid_command regression fixture predates that change and fails
  # the package's build-time test suite. Upstream nixpkgs fix pending —
  # revisit dropping this override once commitizen/nixpkgs catch up.
  commitizen = pkgs.commitizen.overridePythonAttrs (old: {
    disabledTests = old.disabledTests ++ [ "test_invalid_command" ];
  });
in
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
