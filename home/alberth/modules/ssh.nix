{ ... }:

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
