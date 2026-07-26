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

  # jdk21 and jdk25 both ship bin/java, bin/javac, etc., so they collide if
  # both land in environment.systemPackages directly. Suffix every binary in
  # each JDK's bin/ with its major version instead (java21, javac21, java25,
  # javac25, ...) so both toolchains coexist with no default `java` picked.
  mkVersionedJdk =
    version: jdk:
    pkgs.runCommand "jdk${version}-versioned" { } ''
      mkdir -p $out/bin
      for f in ${jdk}/bin/*; do
        ln -s "$f" "$out/bin/$(basename "$f")${version}"
      done
    '';
  jdk21-versioned = mkVersionedJdk "21" pkgs.jdk21;
  jdk25-versioned = mkVersionedJdk "25" pkgs.jdk25;
in
{
  environment.systemPackages = with pkgs; [
    black
    cargo
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
    jdk21-versioned
    jdk25-versioned
    lazygit
    nil
    nmap
    pre-commit
    prettier
    pyenv
    pylint
    pyrefly
    rbenv
    rustc
    shellcheck
    yaml-language-server
    yamllint
  ];
}
