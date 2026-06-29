{ pkgs, lib, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        IdentityFile = [
          "~/.ssh/id_rsa"
        ];
        # GSSAPI — Linux only. Apple's OpenSSH has GSSAPI removed; the
        # options cause "Unsupported option" warnings on darwin and do
        # nothing. Re-enable on darwin once pkgs.openssh replaces the
        # system SSH or the macOS Kerberos/DNS issue is resolved.
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        GSSAPIAuthentication = "yes";
        GSSAPIDelegateCredentials = "yes";
      };
      "github.com" = {
        User = "git";
        # Two identity files: primary key first, rate-limit key as fallback.
        # SSH tries all IdentityFile entries for matching Host blocks.
        IdentityFile = [
          "~/.ssh/github-ssh-key"
          "~/.ssh/github-ratelimit"
        ];
      };
    };
  };
}
