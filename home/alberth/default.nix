{
  config,
  pkgs,
  lib,
  catppuccin-bat,
  ...
}:

let
  # Source user metadata from the central roster so email and GPG key
  # are defined in exactly one place.
  userDefs = import ../../users.nix;
  primaryUser = userDefs.primaryUser;
  user = userDefs.${primaryUser};
  rebuildCmd = if pkgs.stdenv.isDarwin then "nh darwin" else "nh os";
  switchCmd =
    if pkgs.stdenv.isDarwin then
      "sudo darwin-rebuild switch --flake"
    else
      "sudo nixos-rebuild switch --flake";
in
{
  imports = [
    ./atuin.nix
    ./chezmoi.nix
    ./devenv.nix
    ./starship.nix
  ];
  home.username = primaryUser;
  home.homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${primaryUser}" else "/home/${primaryUser}";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Man pages with pre-built cache for fast `man -k` lookups
  programs.man = {
    enable = true;
    generateCaches = true;
  };

  # XDG base directories — moves config, cache, and data out of ~ for
  # any program that respects the XDG spec (git, direnv, etc.)
  xdg.enable = true;

  # Environment variables — applied to all shells
  home.sessionVariables = {
    ALTERNATE_EDITOR = "";
    EDITOR = "nvim";
    VISUAL = "zed -w";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    CLICOLOR = "1";
  };

  # Aliases — applied to all shells
  home.shellAliases = {
    search = ''rg -p --glob "!node_modules/*" --glob "!vendor/*"'';
    cat = "bat";
    nixpull = "pushd $HOME/Projects/nixie && git pull && popd";
  };

  # nixbuild — build the nixie flake for the current host.
  # Defined per-shell because fish uses (hostname) while bash/zsh use $(hostname).
  programs.bash.shellAliases.nixbuild = "pushd $HOME/Projects/nixie && ${rebuildCmd} build .#$(hostname) && popd";
  programs.zsh.shellAliases.nixbuild = "pushd $HOME/Projects/nixie && ${rebuildCmd} build .#$(hostname) && popd";
  programs.fish.shellAliases.nixbuild = "pushd $HOME/Projects/nixie && ${rebuildCmd} build .#(hostname) && popd";

  programs.bash.shellAliases.nixswitch = "pushd $HOME/Projects/nixie && ${switchCmd} .#$(hostname) && popd";
  programs.zsh.shellAliases.nixswitch = "pushd $HOME/Projects/nixie && ${switchCmd} .#$(hostname) && popd";
  programs.fish.shellAliases.nixswitch = "pushd $HOME/Projects/nixie && ${switchCmd} .#(hostname) && popd";

  # User packages not managed via programs.* options
  home.packages =
    with pkgs;
    [
      # Communication
      telegram-desktop

      # Tools
      htop # interactive process viewer
      imagemagick # image manipulation
      pandoc # universal document converter
      ragenix # ragenix CLI — rekey secrets, add recipients
      ripgrep # fast recursive search (rg)

      # Fonts — those without nixpkgs equivalents stay as homebrew casks
      anonymousPro
      font-awesome
      hack-font
      inconsolata
      jetbrains-mono
      liberation_ttf
      nerd-fonts.dejavu-sans-mono
      nerd-fonts.hack
      nerd-fonts.inconsolata-go
      nerd-fonts.jetbrains-mono
    ]
    # Linux-only packages (no Darwin build in nixpkgs)
    ++ lib.optionals pkgs.stdenv.isLinux (
      with pkgs;
      [
        vlc
      ]
    )
    # x86_64-Linux-only packages (no aarch64-linux or Darwin build in nixpkgs)
    ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 (
      with pkgs;
      [
        slack
        zoom-us
        spotify
      ]
    );

  # Extra PATH entries — applied to all shells via home.sessionPath
  home.sessionPath = [
    "$HOME/.cargo/bin"
    "$HOME/.pnpm-packages/bin"
    "$HOME/.pnpm-packages"
    "$HOME/.npm-packages/bin"
    "$HOME/bin"
    "$HOME/.composer/vendor/bin"
    "$HOME/.local/share/bin"
    "$HOME/.local/share/src/conductly/bin"
    "$HOME/.local/share/src/conductly/utils"
  ];

  # Git
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

  # GitHub CLI
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

  # GPG — enable home-manager management of ~/.gnupg
  programs.gpg.enable = true;

  # Import GPG public key on first activation.
  # Tries WKD (domain-hosted) first; falls back to keys.openpgp.org.
  # Skipped if the key is already in the keyring (idempotent).
  home.activation.importGpgKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _gpgBin="${pkgs.gnupg}/bin/gpg"
    _key="${user.gpgSigningKey}"
    _email="${user.email}"

    if ! "$_gpgBin" --list-keys "$_key" > /dev/null 2>&1; then
      echo "GPG: importing key $_key for $_email..."
      "$_gpgBin" --auto-key-locate wkd --locate-key "$_email" 2>/dev/null \
        || "$_gpgBin" --keyserver hkps://keys.openpgp.org --recv-keys "$_key" \
        || echo "GPG: warning — could not import key $_key (no network?)"
    fi

    # Ensure ultimate trust is set (safe to run every time)
    echo "$_key:6:" | "$_gpgBin" --import-ownertrust 2>/dev/null || true
  '';

  # SSH client
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
      };
      "github.com" = {
        # Two identity files: primary key first, rate-limit key as fallback.
        # SSH tries all IdentityFile entries for matching Host blocks.
        IdentityFile = [
          "~/.ssh/github-ssh-key"
          "~/.ssh/github-ratelimit"
        ];
      };
    };
  };

  # Shells
  programs.bash = {
    enable = true;
    historySize = 5000;
    historyFileSize = 5000;
    # erasedups covers ignoreAllDups; ignorespace covers ignoreSpace
    historyControl = [
      "erasedups"
      "ignorespace"
    ];
  };
  programs.fish.enable = true;

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

  # Starship — cross-shell prompt replacing Powerlevel10k
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  # ls → eza wrapper for bash; rewrites -t (standalone or combined) to --sort=newest
  programs.bash.profileExtra = ''
    # Source Nix daemon environment if present (needed on macOS / non-NixOS)
    if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
    fi

    export HISTIGNORE="pwd:ls:cd"
    export PYTHONPATH="$HOME/.local-pip/packages:$PYTHONPATH"
  '';

  programs.bash.initExtra = ''
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

  programs.fish.interactiveShellInit = ''
    # GPG
    set -gx GPG_TTY (tty)

    # Architecture flags
    set -gx ARCHFLAGS "-arch "(uname -m)

    # 1Password shell plugins
    if test -f "$HOME/.config/op/plugins.sh"
      source "$HOME/.config/op/plugins.sh"
    end
  '';

  programs.fish.shellInit = ''
    # History: fish deduplicates and shares across sessions by default.
    # Ignore commands prefixed with a space and cap history size.
    set -g fish_history_max_size 5000
    set -g fish_history_ignore_space 1
  '';

  programs.fish.loginShellInit = ''
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

  # ls → eza wrapper for fish; rewrites -t (standalone or combined) to --sort=newest
  programs.fish.functions.ls = {
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

  # eza (modern ls replacement) with shell integrations
  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    icons = "auto";
    git = true;
    extraOptions = [ "--header" ];
  };

  # fzf with shell integrations
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  # Nushell
  programs.nushell.enable = true;

  # bat — a cat clone with syntax highlighting
  programs.bat = {
    enable = true;
    config = {
      # auto: switches between light/dark based on terminal colour scheme
      # light = Catppuccin Macchiato, dark = Catppuccin Latte
      theme = "auto:Catppuccin Macchiato,Catppuccin Latte";
      italic-text = "always";
    };
    themes = {
      "Catppuccin Latte" = {
        src = catppuccin-bat;
        file = "themes/Catppuccin Latte.tmTheme";
      };
      "Catppuccin Macchiato" = {
        src = catppuccin-bat;
        file = "themes/Catppuccin Macchiato.tmTheme";
      };
    };
  };

  # btop — resource monitor
  programs.btop.enable = true;

  # tealdeer (tldr client) with auto-update
  programs.tealdeer = {
    enable = true;
    settings.updates.auto_update = true;
  };

  # zoxide — smarter cd, aliased to cd across all shells
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    options = [ "--cmd cd" ];
  };

  # direnv with shell integrations
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  # Catppuccin — global flavor; enable for all supported tools we use.
  # bat uses a custom auto light/dark config and is intentionally left out here.
  # neovim is handled inside nvf.nix with its own catppuccin-mocha setup.
  catppuccin = {
    flavor = "macchiato";
    accent = "blue";
    autoEnable = false;
  };

  catppuccin.fzf.enable = true;
  catppuccin.fish.enable = true;
  catppuccin.eza.enable = true;
  catppuccin.zsh-syntax-highlighting.enable = true;
  catppuccin.btop.enable = true;
  catppuccin.starship.enable = true;

  home.stateVersion = "25.05";
}
