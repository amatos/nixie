_:

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
        # GSSAPI — Kerberos ticket forwarding.  Both platforms use
        # pkgs.openssh_gssapi (added to home.packages) which shadows
        # the nix-installed pkgs.openssh that lacks GSSAPI support.
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
      "unifi.home.matos.cc unifi" = {
        User = "root";
      };
    };
  };
}
