{ config, ... }:

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
        name = user.description;
        inherit (user) email;
      };
      core = {
        editor = "nvim";
        autocrlf = "input";
        whitespace = "trailing-space,space-before-tab"; # Highlight whitespace issues
        hooksPath = "${config.home.homeDirectory}/.config/git/template/hooks"; # Global hooks for ALL repos
      };
      init = {
        defaultBranch = "main";
        templateDir = "${config.home.homeDirectory}/.config/git/template/repo";
      };
      commit.gpgSign = true;
      tag.gpgSign = true;
      pull.rebase = true;
      rebase.autoStash = true;
      push.autoSetupRemote = true;
      maintenance.auto = true;
      maintenance.strategy = "incremental";
      # Fetch behavior
      fetch = {
        prune = true; # Auto-remove deleted remote branches
        pruneTags = true; # Auto-remove deleted remote tags
      };
      diff = {
        algorithm = "histogram"; # Better diff algorithm than default
        colorMoved = "default"; # Highlight moved lines in different color
        mnemonicPrefix = true; # Use i/w/c/o instead of a/b in diffs
      };
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
