# certbot-dns-luadns — not in nixpkgs; packaged locally.
# Uses dns-lexicon (which IS in nixpkgs) to talk to the LuaDNS API.
# Source: certbot monorepo on GitHub (not published as a sdist to PyPI).
#
# To update: change version, set hash = lib.fakeHash, rebuild — the error
# output will contain the correct hash to substitute.
{ lib, buildPythonPackage, fetchFromGitHub, certbot, acme, dns-lexicon, setuptools }:

buildPythonPackage rec {
  pname   = "certbot-dns-luadns";
  version = "2.11.0";

  src = fetchFromGitHub {
    owner = "certbot";
    repo  = "certbot";
    rev   = "v${version}";
    hash  = "sha256-Qee7lUjgliG5fmUWWPm3MzpGJHUF/DXZ08UA6kkWjjk=";
  };

  # Plugin lives in a subdirectory of the certbot monorepo
  sourceRoot = "source/certbot-dns-luadns";

  pyproject    = true;
  build-system = [ setuptools ];
  dependencies = [ certbot acme dns-lexicon ];
  doCheck      = false;

  meta = {
    description = "LuaDNS DNS Authenticator plugin for Certbot";
    homepage    = "https://github.com/certbot/certbot/tree/master/certbot-dns-luadns";
    license     = lib.licenses.asl20;
  };
}
