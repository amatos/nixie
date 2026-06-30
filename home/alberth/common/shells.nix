{ pkgs, ... }:

let
  userDefs = import ../../../users.nix;
  inherit (userDefs) primaryUser;
  rebuildCmd = if pkgs.stdenv.isDarwin then "nh darwin" else "nh os";
  switchCmd =
    if pkgs.stdenv.isDarwin then
      "sudo darwin-rebuild switch --flake"
    else
      "sudo nixos-rebuild switch --flake";
in
{
  # Aliases applied to all shells
  home.shellAliases = {
    search = ''rg -p --glob "!node_modules/*" --glob "!vendor/*"'';
    cat = "bat";
    nixpull = "pushd $HOME/Projects/nixie && git pull && popd";
    nixpush = "pushd $HOME/Projects/nixie && git push && popd";
    nixflakeup = "pushd $HOME/Projects/nixie && nix flake update && git add flake.lock && git commit -m 'chore: updated flake.lock' && git push && popd";
    npbs = "nixpull && nixbuild && nixswitch";
    ragenix = "ragenix -i ~/.config/age/yubikey-identity.txt";
  };

  # nixbuild / nixswitch — per-shell because fish uses (hostname) not $(hostname)
  programs.bash.shellAliases.nixbuild = "pushd $HOME/Projects/nixie && ${rebuildCmd} build .#$(hostname) && popd";
  programs.zsh.shellAliases.nixbuild = "pushd $HOME/Projects/nixie && ${rebuildCmd} build .#$(hostname) && popd";
  programs.fish.shellAliases.nixbuild = "pushd $HOME/Projects/nixie && ${rebuildCmd} build .#(hostname) && popd";

  programs.bash.shellAliases.nixswitch = "pushd $HOME/Projects/nixie && ${switchCmd} .#$(hostname) && popd";
  programs.zsh.shellAliases.nixswitch = "pushd $HOME/Projects/nixie && ${switchCmd} .#$(hostname) && popd";
  programs.fish.shellAliases.nixswitch = "pushd $HOME/Projects/nixie && ${switchCmd} .#(hostname) && popd";

  # Bash
  programs.bash = {
    enable = true;
    historySize = 5000;
    historyFileSize = 5000;
    # erasedups covers ignoreAllDups; ignorespace covers ignoreSpace
    historyControl = [
      "erasedups"
      "ignorespace"
    ];
    profileExtra = ''
      # Source Nix daemon environment if present (needed on macOS / non-NixOS)
      if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      fi

      export HISTIGNORE="pwd:ls:cd"
      export PYTHONPATH="$HOME/.local-pip/packages:$PYTHONPATH"
    '';
    initExtra = ''
      # Share history across sessions (append on each command, reload before each prompt)
      shopt -s histappend
      PROMPT_COMMAND="''${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a; history -c; history -r"

      # GPG
      export GPG_TTY=$(tty)

      # Architecture flags
      export ARCHFLAGS="-arch $(uname -m)"

      # 1Password shell plugins
      [ -f "$HOME/.config/op/plugins.sh" ] && source "$HOME/.config/op/plugins.sh"

      function ls {
        local args=()
        for arg in "$@"; do
          if [[ "$arg" =~ ^-[a-zA-Z]*t[a-zA-Z]*$ ]]; then
            local stripped="''${arg//t/}"
            [[ "$stripped" != "-" ]] && args+=("$stripped")
            args+=("--sort=newest")
          else
            args+=("$arg")
          fi
        done
        eza "''${args[@]}"
      }
    '';
  };

  # Zsh
  programs.zsh = {
    enable = true;
    dotDir =
      if pkgs.stdenv.isDarwin then
        "/Users/${primaryUser}/.config/zsh"
      else
        "/home/${primaryUser}/.config/zsh";

    history = {
      size = 5000;
      save = 5000;
      path = "$HOME/.zsh_history";
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      share = true;
      expireDuplicatesFirst = true;
    };

    envExtra = ''
      export HISTIGNORE="pwd:ls:cd"
      export PYTHONPATH="$HOME/.local-pip/packages:$PYTHONPATH"
    '';
    autocd = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      # Completion styling
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
      zstyle ':completion:*' menu no
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
      zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

      # fzf-tab (must load after compinit)
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh

      # GPG
      export GPG_TTY=$(tty)

      # Architecture flags
      export ARCHFLAGS="-arch $(uname -m)"

      # 1Password shell plugins
      [ -f "$HOME/.config/op/plugins.sh" ] && source "$HOME/.config/op/plugins.sh"

      # ls → eza wrapper; rewrites -t (standalone or combined) to --sort=newest
      ls() {
        local args=()
        for arg in "$@"; do
          if [[ "$arg" =~ ^-[a-zA-Z]*t[a-zA-Z]*$ ]]; then
            local stripped="''${arg//t/}"
            [[ "$stripped" != "-" ]] && args+=("$stripped")
            args+=("--sort=newest")
          else
            args+=("$arg")
          fi
        done
        eza "''${args[@]}"
      }
    '';
  };

  # Fish
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # GPG
      set -gx GPG_TTY (tty)

      # Architecture flags
      set -gx ARCHFLAGS "-arch "(uname -m)

      # 1Password shell plugins
      if test -f "$HOME/.config/op/plugins.sh"
        source "$HOME/.config/op/plugins.sh"
      end
    '';
    shellInit = ''
      # History: fish deduplicates and shares across sessions by default.
      # Ignore commands prefixed with a space and cap history size.
      set -g fish_history_max_size 5000
      set -g fish_history_ignore_space 1
    '';
    loginShellInit = ''
      # Source Nix daemon environment if present (needed on macOS / non-NixOS)
      if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
      end

      # PYTHONPATH
      if set -q PYTHONPATH
        set -gx PYTHONPATH "$HOME/.local-pip/packages:$PYTHONPATH"
      else
        set -gx PYTHONPATH "$HOME/.local-pip/packages"
      end
    '';
    # ls → eza wrapper; rewrites -t (standalone or combined) to --sort=newest
    functions.ls = {
      description = "eza wrapper — rewrites -t (standalone or combined) to --sort=newest";
      body = ''
        set -l args
        for arg in $argv
          if string match -rq '^-[a-zA-Z]*t[a-zA-Z]*$' -- $arg
            set stripped (string replace -a t "" $arg)
            if test "$stripped" != "-"
              set args $args $stripped
            end
            set args $args --sort=newest
          else
            set args $args $arg
          end
        end
        eza $args
      '';
    };
  };
}
