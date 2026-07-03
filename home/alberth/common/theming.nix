{ lib, ... }:

# Theming — Dracula (https://draculatheme.com) across every tool that has a
# variant available. bat (home/alberth/common/tools.nix), neovim (nvf.nix),
# and Ghostty (home/alberth/darwin/ghostty.nix) bundle a "dracula" theme
# natively and are configured at their own call sites. The tools below have
# no first-party nix module for Dracula (unlike Catppuccin, which shipped
# catppuccin/nix), so their official colors/theme files are embedded here
# directly instead of pulling in a new flake input per tool.
{
  # eza — Dracula theme.yml (eza-community/eza-themes, themes/dracula.yml).
  xdg.configFile."eza/theme.yml".text = ''
    colourful: true
    # yellow #F1FA8C
    # red    #FF5555
    # purple #BD93F9
    # pink   #FF79C6
    # orange #FFB86C
    # green  #50FA7B
    # cyan   #8BE9FD
    # others:
    # dark-blue    #6272A4
    # foreground   #F8F8F2
    # current_line #44475A

    filekinds:
      normal: {foreground: "#F8F8F2"}
      directory: {foreground: "#8BE9FD"}
      symlink: {foreground: "#BD93F9"}
      pipe: {foreground: "#6272A4"}
      block_device: {foreground: "#FF5555"}
      char_device: {foreground: "#FF5555"}
      socket: {foreground: "#44475A"}
      special: {foreground: "#FF79C6"}
      executable: {foreground: "#50FA7B"}
      mount_point: {foreground: "#FFB86C"}

    perms:
      user_read: {foreground: "#F8F8F2"}
      user_write: {foreground: "#FFB86C"}
      user_execute_file: {foreground: "#50FA7B"}
      user_execute_other: {foreground: "#50FA7B"}
      group_read: {foreground: "#F8F8F2"}
      group_write: {foreground: "#FFB86C"}
      group_execute: {foreground: "#50FA7B"}
      other_read: {foreground: "#F8F8F2"}
      other_write: {foreground: "#FFB86C"}
      other_execute: {foreground: "#50FA7B"}
      special_user_file: {foreground: "#FF79C6"}
      special_other: {foreground: "#6272A4"}
      attribute: {foreground: "#F8F8F2"}

    size:
      major: {foreground: "#F1FA8C"}
      minor: {foreground: "#BD93F9"}
      number_byte: {foreground: "#F8F8F2"}
      number_kilo: {foreground: "#F8F8F2"}
      number_mega: {foreground: "#8BE9FD"}
      number_giga: {foreground: "#FF79C6"}
      number_huge: {foreground: "#FF79C6"}
      unit_byte: {foreground: "#F8F8F2"}
      unit_kilo: {foreground: "#8BE9FD"}
      unit_mega: {foreground: "#FF79C6"}
      unit_giga: {foreground: "#FF79C6"}
      unit_huge: {foreground: "#FFB86C"}

    users:
      user_you: {foreground: "#F8F8F2"}
      user_root: {foreground: "#FF5555"}
      user_other: {foreground: "#FF79C6"}
      group_yours: {foreground: "#F8F8F2"}
      group_other: {foreground: "#6272A4"}
      group_root: {foreground: "#FF5555"}

    links:
      normal: {foreground: "#BD93F9"}
      multi_link_file: {foreground: "#FFB86C"}

    git:
      new: {foreground: "#50FA7B"}
      modified: {foreground: "#FFB86C"}
      deleted: {foreground: "#FF5555"}
      renamed: {foreground: "#8BE9FD"}
      typechange: {foreground: "#FF79C6"}
      ignored: {foreground: "#6272A4"}
      conflicted: {foreground: "#FF5555"}

    git_repo:
      branch_main: {foreground: "#F8F8F2"}
      branch_other: {foreground: "#FF79C6"}
      git_clean: {foreground: "#50FA7B"}
      git_dirty: {foreground: "#FF5555"}

    security_context:
      colon: {foreground: "#6272A4"}
      user: {foreground: "#F8F8F2"}
      role: {foreground: "#FF79C6"}
      typ: {foreground: "#6272A4"}
      range: {foreground: "#FF79C6"}

    file_type:
      image: {foreground: "#FFB86C"}
      video: {foreground: "#FF5555"}
      music: {foreground: "#50FA7B"}
      lossless: {foreground: "#50FA7B"}
      crypto: {foreground: "#6272A4"}
      document: {foreground: "#F8F8F2"}
      compressed: {foreground: "#FF79C6"}
      temp: {foreground: "#FF5555"}
      compiled: {foreground: "#8BE9FD"}
      build: {foreground: "#6272A4"}
      source: {foreground: "#8BE9FD"}

    punctuation: {foreground: "#6272A4"}
    date: {foreground: "#FFB86C"}
    inode: {foreground: "#F8F8F2"}
    blocks: {foreground: "#F8F8F2"}
    header: {foreground: "#F8F8F2"}
    octal: {foreground: "#50FA7B"}
    flags: {foreground: "#FF79C6"}

    symlink_path: {foreground: "#BD93F9"}
    control_char: {foreground: "#8BE9FD"}
    broken_symlink: {foreground: "#FF5555"}
    broken_path_overlay: {foreground: "#6272A4"}
  '';

  # fish — "Dracula Official" theme (dracula/fish), installed as a theme file
  # and selected the same way `fish_config theme choose` would.
  xdg.configFile."fish/themes/Dracula Official.theme".text = ''
    # Dracula Color Palette
    #
    # Foreground: f8f8f2
    # Selection: 44475a
    # Comment: 6272a4
    # Red: ff5555
    # Orange: ffb86c
    # Yellow: f1fa8c
    # Green: 50fa7b
    # Purple: bd93f9
    # Cyan: 8be9fd
    # Pink: ff79c6

    # Syntax Highlighting Colors
    fish_color_normal f8f8f2
    fish_color_command 8be9fd
    fish_color_keyword ff79c6
    fish_color_quote f1fa8c
    fish_color_redirection f8f8f2
    fish_color_end ffb86c
    fish_color_error ff5555
    fish_color_param bd93f9
    fish_color_comment 6272a4
    fish_color_selection --background=44475a
    fish_color_search_match --background=44475a
    fish_color_operator 50fa7b
    fish_color_escape ff79c6
    fish_color_autosuggestion 6272a4
    fish_color_cancel ff5555 --reverse
    fish_color_option ffb86c
    fish_color_history_current --bold
    fish_color_status ff5555
    fish_color_valid_path --underline

    # Default Prompt Colors
    fish_color_cwd 50fa7b
    fish_color_cwd_root red
    fish_color_host bd93f9
    fish_color_host_remote bd93f9
    fish_color_user 8be9fd

    # Completion Pager Colors
    fish_pager_color_progress 6272a4
    fish_pager_color_background
    fish_pager_color_prefix 8be9fd
    fish_pager_color_completion f8f8f2
    fish_pager_color_description 6272a4
    fish_pager_color_selected_background --background=44475a
    fish_pager_color_selected_prefix 8be9fd
    fish_pager_color_selected_completion f8f8f2
    fish_pager_color_selected_description 6272a4
    fish_pager_color_secondary_background
    fish_pager_color_secondary_prefix 8be9fd
    fish_pager_color_secondary_completion f8f8f2
    fish_pager_color_secondary_description 6272a4
  '';
  programs.fish.shellInit = ''
    fish_config theme choose "Dracula Official"
  '';

  # fzf — official Dracula colors (draculatheme.com/fzf), via home-manager's
  # native programs.fzf.colors (adds --color to FZF_DEFAULT_OPTS).
  programs.fzf.colors = {
    fg = "#f8f8f2";
    bg = "#282a36";
    hl = "#bd93f9";
    "fg+" = "#f8f8f2";
    "bg+" = "#44475a";
    "hl+" = "#bd93f9";
    info = "#ffb86c";
    prompt = "#50fa7b";
    pointer = "#ff79c6";
    marker = "#ff79c6";
    spinner = "#ffb86c";
    header = "#6272a4";
  };

  # btop — community Dracula theme, written via home-manager's native
  # programs.btop.themes (btop itself bundles no Dracula variant).
  programs.btop = {
    themes.dracula = ''
      theme[main_bg]="#282a36"
      theme[main_fg]="#f8f8f2"
      theme[title]="#f8f8f2"
      theme[hi_fg]="#6272a4"
      theme[selected_bg]="#ff79c6"
      theme[selected_fg]="#f8f8f2"
      theme[inactive_fg]="#44475a"
      theme[graph_text]="#f8f8f2"
      theme[meter_bg]="#44475a"
      theme[proc_misc]="#bd93f9"
      theme[cpu_box]="#bd93f9"
      theme[mem_box]="#50fa7b"
      theme[net_box]="#ff5555"
      theme[proc_box]="#8be9fd"
      theme[div_line]="#44475a"
      theme[temp_start]="#bd93f9"
      theme[temp_mid]="#ff79c6"
      theme[temp_end]="#ff33a8"
      theme[cpu_start]="#bd93f9"
      theme[cpu_mid]="#8be9fd"
      theme[cpu_end]="#50fa7b"
      theme[free_start]="#ffa6d9"
      theme[free_mid]="#ff79c6"
      theme[free_end]="#ff33a8"
      theme[cached_start]="#b1f0fd"
      theme[cached_mid]="#8be9fd"
      theme[cached_end]="#26d7fd"
      theme[available_start]="#ffd4a6"
      theme[available_mid]="#ffb86c"
      theme[available_end]="#ff9c33"
      theme[used_start]="#96faaf"
      theme[used_mid]="#50fa7b"
      theme[used_end]="#0dfa49"
      theme[download_start]="#bd93f9"
      theme[download_mid]="#50fa7b"
      theme[download_end]="#8be9fd"
      theme[upload_start]="#8c42ab"
      theme[upload_mid]="#ff79c6"
      theme[upload_end]="#ff33a8"
      theme[process_start]="#50fa7b"
      theme[process_mid]="#59b690"
      theme[process_end]="#6272a4"
    '';
    settings.color_theme = "dracula";
  };

  # zsh-syntax-highlighting — Dracula styles (dracula/zsh-syntax-highlighting).
  # mkOrder 950 mirrors the order the former catppuccin.zsh-syntax-highlighting
  # module used, so it still loads before home-manager's syntaxHighlighting init.
  programs.zsh.initContent = lib.mkOrder 950 ''
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main cursor)
    typeset -gA ZSH_HIGHLIGHT_STYLES
    ZSH_HIGHLIGHT_STYLES[comment]='fg=#6272A4'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=#50FA7B'
    ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#50FA7B'
    ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#50FA7B'
    ZSH_HIGHLIGHT_STYLES[function]='fg=#50FA7B'
    ZSH_HIGHLIGHT_STYLES[command]='fg=#50FA7B'
    ZSH_HIGHLIGHT_STYLES[precommand]='fg=#50FA7B,italic'
    ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#FFB86C,italic'
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#FFB86C'
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#FFB86C'
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#BD93F9'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=#8BE9FD'
    ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#8BE9FD'
    ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#8BE9FD'
    ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#FF79C6'
    ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#FF79C6'
    ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#FF79C6'
    ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#FF79C6'
    ZSH_HIGHLIGHT_STYLES[command-substitution-quoted]='fg=#F1FA8C'
    ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-quoted]='fg=#F1FA8C'
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#F1FA8C'
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]='fg=#FF5555'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#F1FA8C'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]='fg=#FF5555'
    ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#F1FA8C'
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument-unclosed]='fg=#FF5555'
    ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[assign]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#FF5555'
    ZSH_HIGHLIGHT_STYLES[path]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#FF79C6'
    ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=#FF79C6'
    ZSH_HIGHLIGHT_STYLES[globbing]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#BD93F9'
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]='fg=#FF5555'
    ZSH_HIGHLIGHT_STYLES[redirection]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[arg0]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[default]='fg=#F8F8F2'
    ZSH_HIGHLIGHT_STYLES[cursor]='standout'
  '';
}
