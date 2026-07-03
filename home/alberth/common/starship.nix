# Starship prompt — powerline segmented layout with Dracula palette.
# Reference: https://github.com/amatos/dotfiles/blob/main/dotfiles/dot_config/starship.toml
#
# Segments (left → right, single line):
#   [os][username] → [directory] → [git branch + status]
#   → [lang tools: c rust go node php java kotlin haskell python]
#   → [conda] → [time]  cmd_duration  nix_shell
#   (newline)
#   λ
_:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  programs.starship.settings = {
    # \n in a Nix regular string is a real newline; home-manager serialises it
    # to TOML as \n which Starship interprets as a line break.
    format = "[](purple)$os$username$hostname[](bg:cyan fg:purple)$directory[](bg:pink fg:cyan)$git_branch$git_status[](fg:pink bg:green)$c$rust$golang$nodejs$php$java$kotlin$haskell$python$nix_shell[](fg:green bg:comment)$conda[](fg:comment bg:comment)$time[](fg:comment)$cmd_duration\n$character";

    palette = "dracula";

    # Dracula colour palette — named tokens used in segment styles above.
    # crust (#11111b) is used as foreground text on bright segment backgrounds.
    palettes.dracula = {
      pink = "#ff79c6";
      red = "#ff5555";
      yellow = "#f1fa8c";
      green = "#50fa7b";
      blue = "#644ac9";
      purple = "#bd93f9";
      cyan = "#8be9fd";
      comment = "#6272a4";
      base = "#1e1e2e";
      mantle = "#181825";
      crust = "#11111b";
    };

    # OS icon — purple segment
    os = {
      disabled = false;
      style = "bg:purple fg:crust";
      symbols = {
        Windows = "";
        Ubuntu = "󰕈";
        SUSE = "";
        Raspbian = "󰐿";
        Mint = "󰣭";
        Macos = "󰀵";
        Manjaro = "";
        Linux = "󰌽";
        Gentoo = "󰣨";
        Fedora = "󰣛";
        Alpine = "";
        Amazon = "";
        Android = "";
        Arch = "󰣇";
        Artix = "󰣇";
        CentOS = "";
        Debian = "󰣚";
        Redhat = "󱄛";
        RedHatEnterprise = "󱄛";
      };
    };

    # Username — always shown, same purple segment as OS
    username = {
      show_always = true;
      style_user = "bg:purple fg:crust";
      style_root = "bg:purple fg:red";
      format = "[ $user]($style)";
    };

    # Hostname — purple segment, always shown
    hostname = {
      ssh_only = false;
      style = "bg:purple fg:crust";
      format = "[@$hostname ]($style)";
    };

    # Directory — cyan segment
    directory = {
      style = "bg:cyan fg:crust";
      format = "[ $path ]($style)";
      truncation_length = 3;
      truncation_symbol = "…/";
      substitutions = {
        "Documents" = "󰈙 ";
        "Downloads" = " ";
        "Music" = "󰝚 ";
        "Pictures" = " ";
        "src" = "󰲋 ";
        "Developer" = "󰲋 ";
      };
    };

    # Git branch — pink segment
    git_branch = {
      symbol = "";
      style = "bg:pink";
      format = "[[ $symbol $branch ](fg:crust bg:pink)]($style)";
    };

    # Git status — pink segment (same block as branch)
    git_status = {
      style = "bg:pink";
      format = "[[($all_status$ahead_behind )](fg:crust bg:pink)]($style)";
    };

    # Language / toolchain segments — green block
    c = {
      symbol = " ";
      style = "bg:green";
      format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
    };

    rust = {
      symbol = "";
      style = "bg:green";
      format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
    };

    golang = {
      symbol = "";
      style = "bg:green";
      format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
    };

    nodejs = {
      symbol = "";
      style = "bg:green";
      format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
    };

    php = {
      symbol = "";
      style = "bg:green";
      format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
    };

    java = {
      symbol = " ";
      style = "bg:green";
      format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
    };

    kotlin = {
      symbol = "";
      style = "bg:green";
      format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
    };

    haskell = {
      symbol = "";
      style = "bg:green";
      format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
    };

    python = {
      symbol = "";
      style = "bg:green";
      format = "[[ $symbol( $version)(\\($virtualenv\\)) ](fg:crust bg:green)]($style)";
    };

    # Conda environment — comment segment
    conda = {
      symbol = "  ";
      style = "fg:crust bg:comment";
      format = "[$symbol$environment ]($style)";
      ignore_base = false;
    };

    # Time — comment segment
    time = {
      disabled = false;
      time_format = "%_I:%M %p";
      style = "bg:comment";
      format = "[[  $time ](fg:crust bg:comment)]($style)";
    };

    line_break.disabled = true;

    # Prompt character — λ green on success, red on failure; ❮ in vi modes
    character = {
      disabled = false;
      success_symbol = "[λ](bold fg:green)";
      error_symbol = "[λ](bold fg:red)";
      vimcmd_symbol = "[❮](bold fg:green)";
      vimcmd_replace_one_symbol = "[❮](bold fg:purple)";
      vimcmd_replace_symbol = "[❮](bold fg:purple)";
      vimcmd_visual_symbol = "[❮](bold fg:yellow)";
    };

    # Command duration — shown inline after the time block
    cmd_duration = {
      disabled = false;
      show_milliseconds = true;
      format = " in $duration ";
      style = "bg:purple";
      show_notifications = true;
      min_time_to_notify = 45000;
    };

    # Nix shell — green segment alongside other language tools
    nix_shell = {
      symbol = " ";
      style = "bg:green";
      format = "[[ $symbol$state( \\($name\\)) ](fg:crust bg:green)]($style)";
      impure_msg = "impure";
      pure_msg = "pure";
    };
  };
}
