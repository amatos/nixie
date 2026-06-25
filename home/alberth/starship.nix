# Starship prompt — mirrors the p10k rainbow config:
#
#   Line 1 left:  ╭─ [os] [dir] [git branch + status]
#   Line 1 right: (·· fill ··) [exit] [duration] [jobs] [direnv] [envs] [context]
#   Line 2:       ╰─ ❯
#
# Approximations vs p10k:
#   - Kubernetes/AWS/Azure/GCloud are always visible when configured (p10k showed
#     them only while typing the relevant command — Starship has no equivalent).
#   - No powerline segment backgrounds; catppuccin.starship handles colors.
{ ... }:

{
  programs.starship.settings = {
    # \n in a Nix regular string is a real newline; home-manager serialises it
    # to TOML as \n which Starship interprets as a line break.
    format = "╭─$os$directory$git_branch$git_commit$git_state$git_status$fill$status$cmd_duration$jobs$direnv$python$nodejs$ruby$golang$rust$java$lua$kubernetes$terraform$aws$azure$gcloud$nix_shell$username$hostname\n╰─$character";

    # Dotted fill matching POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR='·'
    fill = {
      symbol = "·";
      style = "dimmed";
    };

    # OS icon (matches os_icon segment)
    os = {
      disabled = false;
      format = "[$symbol ]($style)";
    };

    # Directory — truncate to unique prefix matching p10k truncate_to_unique strategy
    directory = {
      format = "[$path]($style)[$read_only]($read_only_style) ";
      truncation_length = 3;
      truncate_to_repo = true;
      truncation_symbol = "…/";
    };

    # Git branch —  nerd font branch icon, "on " prefix matching p10k VCS_PREFIX
    git_branch = {
      format = "[on ](dimmed)[$symbol$branch(:$remote_branch)]($style) ";
      symbol = " ";
    };

    # Detached HEAD — show short commit hash (tag with # prefix if on a tag)
    git_commit = {
      format = "[@$hash$tag]($style) ";
      only_detached = true;
      tag_disabled = false;
      tag_symbol = "#";
    };

    # In-progress git operations (merge, rebase, cherry-pick, etc.)
    git_state = {
      format = "[$state( $progress_current/$progress_total)]($style) ";
    };

    # Git status — matches p10k symbols: ⇡⇣ ahead/behind, * stash, ~ conflicts,
    # + staged, ! unstaged, ? untracked
    git_status = {
      format = "([$all_status$ahead_behind]($style) )";
      conflicted = "~$count";
      ahead = "⇡$count";
      behind = "⇣$count";
      diverged = "⇣$behind_count⇡$ahead_count";
      untracked = "?$count";
      stashed = "*$count";
      modified = "!$count";
      staged = "+$count";
      renamed = "";
      deleted = "";
    };

    # Exit status — ✔ on success, ✘ on failure (matches p10k STATUS_OK / STATUS_ERROR)
    status = {
      disabled = false;
      format = "$symbol ";
      success_symbol = "[✔](bold green)";
      symbol = "[✘](bold red)";
      map_symbol = true;
    };

    # Command duration — 3 s threshold, integer display (matches p10k threshold=3, precision=0)
    cmd_duration = {
      min_time = 3000;
      format = "[took $duration]($style) ";
      show_milliseconds = false;
    };

    # Background jobs
    jobs = {
      format = "[$symbol$number]($style) ";
      symbol = "⚙";
      number_threshold = 1;
      symbol_threshold = 1;
    };

    # direnv
    direnv = {
      disabled = false;
      format = "[$symbol$loaded/$allowed]($style) ";
      symbol = "direnv ";
      loaded_msg = "✔";
      unloaded_msg = "✘";
      allowed_msg = "✔";
      not_allowed_msg = "✘";
    };

    # Python — virtualenv / pyenv
    python = {
      format = "[$symbol$pyenv_prefix$version( \\($virtualenv\\))]($style) ";
      symbol = " ";
      detect_files = [ ".python-version" "requirements.txt" "pyproject.toml" "Pipfile" "setup.py" "setup.cfg" "tox.ini" ];
    };

    # Node.js — nvm / nodenv / .nvmrc
    nodejs = {
      format = "[$symbol$version]($style) ";
      symbol = " ";
      detect_files = [ "package.json" ".node-version" ".nvmrc" ];
    };

    # Ruby — rbenv / rvm
    ruby = {
      format = "[$symbol$version]($style) ";
      symbol = " ";
    };

    # Go — goenv
    golang = {
      format = "[$symbol$version]($style) ";
      symbol = " ";
      detect_files = [ "go.mod" "go.sum" "go.work" ".go-version" ];
    };

    # Rust
    rust = {
      format = "[$symbol$version]($style) ";
      symbol = " ";
    };

    # Java — jenv
    java = {
      format = "[$symbol$version]($style) ";
      symbol = " ";
      detect_files = [ "pom.xml" "build.gradle" "build.gradle.kts" ".java-version" ];
    };

    # Lua — luaenv
    lua = {
      format = "[$symbol$version]($style) ";
      symbol = " ";
      detect_files = [ ".lua-version" ];
    };

    # Kubernetes context (matches p10k kubecontext, cloud-cluster name preferred)
    kubernetes = {
      disabled = false;
      format = "[at ☸ $context(/$namespace)]($style) ";
    };

    # Terraform workspace
    terraform = {
      format = "[$symbol$workspace]($style) ";
      symbol = "󱁢 ";
    };

    # AWS profile + region
    aws = {
      format = "[$symbol($profile )(\\[$duration\\] )]($style)";
      symbol = " ";
    };

    # Azure subscription
    azure = {
      disabled = false;
      format = "[$symbol($subscription)]($style) ";
      symbol = "󰠅 ";
    };

    # Google Cloud project
    gcloud = {
      format = "[$symbol$account(@$domain)(\\($project\\))]($style) ";
      symbol = " ";
    };

    # Nix shell — matches p10k nix_shell segment
    nix_shell = {
      format = "[$symbol$state( \\($name\\))]($style) ";
      symbol = " ";
      impure_msg = "impure";
      pure_msg = "pure";
    };

    # user@hostname — shown only in SSH or as root (matches p10k CONTEXT_{DEFAULT,SUDO}_*_EXPANSION=)
    username = {
      show_always = false;
      format = "[$user]($style)";
    };
    hostname = {
      ssh_only = true;
      format = "[@$hostname ]($style)";
    };

    # Prompt character — ❯ green on success, red on failure; ❮ in vi normal mode
    character = {
      success_symbol = "[❯](bold green)";
      error_symbol = "[❯](bold red)";
      vimcmd_symbol = "[❮](bold green)";
      vimcmd_replace_symbol = "[❮](bold red)";
      vimcmd_visual_symbol = "[V](bold blue)";
    };
  };
}
