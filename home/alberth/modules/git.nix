{ ... }:

let
  userDefs = import ../../../users.nix;
  user = userDefs.${userDefs.primaryUser};
in
{
  programs.git = {
    enable = true;
    signing = {
      key = user.gpgSigningKey;
      signByDefault = true;
    };
    lfs.enable = true;
    ignores = [
      "*.swp"
      ".DS_Store"
    ];
    settings = {
      user = {
        name = "Alberth Matos";
        email = user.email;
      };
      core = {
        editor = "nvim";
        autocrlf = "input";
      };
      init.defaultBranch = "main";
      commit.gpgSign = true;
      tag.gpgSign = true;
      pull.rebase = true;
      rebase.autoStash = true;
      push.autoSetupRemote = true;
      maintenance.auto = true;
      maintenance.strategy = "incremental";
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "zed";
      prompt = "enabled";
      prefer_editor_prompt = "disabled";
      pager = "bat";
      aliases = {
        co = "pr checkout";
      };
      color_labels = "enabled";
      accessible_colors = "disabled";
      accessible_prompter = "disabled";
      spinner = "enabled";
    };
  };
}
