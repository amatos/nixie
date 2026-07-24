# Homebrew Configuration
#
# Homebrew is a FALLBACK ONLY for packages not in nixpkgs or severely outdated.
# Prefer nixpkgs for everything - only use homebrew when absolutely necessary.
#
# == Update Philosophy ==
#
# Packages are kept current via `brew autoupdate` (homebrew/autoupdate tap), which
# runs `brew update && brew upgrade --greedy --cleanup` every 30 hours in the
# background via a launchd LaunchAgent. The autoupdate plist is (re)created on
# every `darwin-rebuild switch` via a postActivation script.
#
# Our configuration:
#   - onActivation.autoUpdate = false  → Keeps rebuilds fast (no 45MB index download)
#   - onActivation.upgrade = false     → Rebuilds don't run brew upgrade (autoupdate handles it)
#   - brew autoupdate: every 30h       → Background upgrade with --greedy --cleanup
#   - Passive auto-update: Enabled     → >5 minutes trigger on command invocation
#
# == How Packages Get Updated ==
#
# 1. AUTOMATIC: brew autoupdate runs every 30 hours (background launchd agent)
# 2. MANUAL: Run `brew update && brew upgrade --greedy` for immediate updates
# 3. RENOVATE: Cannot track homebrew versions (no version info in this config)
#
# == Why Renovate Can't Help ==
#
# nix-darwin homebrew config contains only package names, not versions.
# Homebrew lacks declarative version pinning within configuration files.
# Renovate's homebrew manager only works with Ruby Formula files.
#
# NOTE: nix-darwin does NOT support version pinning for individual homebrew packages.
# To prevent upgrades for a specific package, pin it via `brew pin <package>`.

{
  lib,
  pkgs,
  nix-home-alberth,
  ...
}:

let
  # 30 hours in seconds — brew autoupdate requires interval in seconds
  autoupdateInterval = 108000;

  configureBrewAutoupdateScript = pkgs.writeShellApplication {
    name = "configure-brew-autoupdate";
    runtimeInputs = [ ];
    text = builtins.readFile "${nix-home-alberth}/alberth/scripts/configure-brew-autoupdate.sh";
  };
in
{
  homebrew = {
    enable = true;
    onActivation = {
      # Don't download 45MB index on every rebuild - keeps rebuilds fast and deterministic.
      # Homebrew's passive auto-update still works (triggers on command invocation after >5 minutes).
      autoUpdate = false;
      cleanup = "uninstall";
      # Upgrades handled by brew autoupdate (every 30h) — not during darwin-rebuild.
      # This keeps rebuilds fast. Run `brew upgrade --greedy` manually for immediate updates.
      upgrade = false;
    };
    taps = [
      "homebrew/autoupdate" # managed via nix-homebrew.taps in codex/default.nix
      {
        # Third-party tap: whole-tap trust required, or `brew cleanup` aborts
        # activation trying to load ANY of its untrusted casks/formulae (even
        # ones not installed/declared) — per-item `trusted = true` on
        # individual casks/brews below is not sufficient on its own.
        name = "cirruslabs/cli";
        trusted = true;
      }
      {
        name = "dracula/install"; # see cirruslabs/cli note above
        trusted = true;
      }
    ];
    brews = [
      "mas" # Mac App Store CLI
      "pinentry-mac" # GPG pinentry with macOS Keychain / Touch ID support
      "cirruslabs/cli/cirrus" # Cirrus CLI (cirruslabs/cli tap)
    ];

    casks = [
      # GUI applications (only if not available in nixpkgs)
      #
      # TCC NOTE: Homebrew casks install directly to /Applications/ (real copies,
      # not symlinks to /nix/store), so macOS TCC permissions (camera, mic, screen
      # recording) persist across darwin-rebuild. This is different from nixpkgs
      # apps which require copyApps workaround in home-manager.
      #
      # No per-cask `greedy` flag: `brew autoupdate` and the manual fallback
      # command both already invoke `brew upgrade --greedy`, which applies
      # greedy behaviour (upgrading casks with a built-in auto-updater too,
      # since those updaters are unreliable in practice) to every cask in this
      # list globally — see "Update Philosophy" above.
      # NOTE: ChatGPT and Cursor are in nixpkgs - see home.packages.
      # NOTE: Antigravity and gemini-cli are in homebrew (above).

      "aldente" # MacOS power control
      "orion" # Safari-based browser
      "dracula/install/dracula-steam" # Dracula theme for Steam
      "dracula/install/dracula-betterdiscord" # Dracula theme for BetterDiscord
      "1password" # Password manager and secure digital wallet
      "1password-cli" # 1Password command-line tool (op)
      "airfoil" # Sends audio from computer to outputs
      "arq" # Multi-cloud backup application
      "audio-hijack" # Records audio from any application
      "automounterhelper" # Helper for AutoMounter to mount shares to custom locations
      "betterdiscord-installer" # Installer for BetterDiscord
      "betterdisplay" # Display management tool
      "bettermouse"
      "bettertouchtool" # Customise touchpad behavior
      "claude" # Anthropic's official Claude AI desktop app
      "claude-code" # Anthropic's official Claude AI CLI app
      "claudebar" # Menu bar app for monitoring AI coding assistant usage quotas
      "cleanshot" # Screen capturing tool
      "cmux" # Native macOS terminal for running AI coding agents in parallel
      "coherence-x" # GUI for managing CrossOver/Wine bottles
      "crossover" # Tool to run Windows software
      "discord" # Voice and text chat software
      "elgato-capture-device-utility" # Update and configure Elgato Capture devices
      "elgato-control-center" # Control Elgato Key Light, Ring Light, and other gear
      "elgato-stream-deck" # Assign keys, and then decorate and label them
      "elgato-studio" # Capture and manage Elgato devices for content creation
      "elgato-wave-link" # Mixer software for Elgato Wave audio devices
      "farrago"
      "fission" # Audio editor
      "focusrite-control-2" # Focusrite interface controller for devices of the 4th generation and newer
      # iosevka fails to build on aarch64-darwin due to a known upstream bug
      # (nixpkgs issue 532294); fall back to Homebrew's prebuilt binary here.
      # x86_64-linux (gammu) is unaffected and uses pkgs.iosevka instead.
      "font-iosevka"
      "font-iosevka-nerd-font" # see font-iosevka note above
      # same upstream build issue as font-iosevka above (ioskeley-mono is
      # built on top of iosevka); Homebrew only ships the base variant, no
      # Term/NerdFont zips like nixpkgs' pkgs.ioskeley-mono attrset
      "font-ioskeley-mono"
      "font-sf-mono-nerd-font-ligaturized" # no nixpkgs equivalent
      "font-tengwar-telcontar"
      "font-zed-mono"
      "font-zed-mono-nerd-font"
      "font-zed-sans"
      "ghostty" # Terminal emulator that uses platform-native UI and GPU acceleration
      "google-chrome"
      "gpg-suite@nightly" # Tools to protect your emails and files
      "hazel" # Automated organisation
      "helium-browser" # Chromium-based web browser
      "hex-fiend" # Hex editor focussing on speed
      "iina" # Free and open-source media player
      "jetbrains-toolbox" # JetBrains tools manager
      "kaleidoscope" # Spot and merge differences in text and image files or folders
      "keyboard-maestro" # Automation software
      "latest" # Utility that shows the latest app updates
      "lingon-x" # GUI for creating and managing launchd jobs
      "little-snitch" # Host-based application firewall
      "lm-studio"
      "loopback" # Loopback audio driver
      "mactex" # Full TeX Live distribution with GUI applications
      "obs" # Open-source software for live streaming and screen recording
      "obsidian" # Knowledge base that works on top of a local folder of plain text Markdown files
      "orbstack"
      "piezo"
      "pixelsnap" # Screen measuring tool
      "plistedit-pro" # Property list and JSON editor
      "popclip"
      "powerphotos" # Tool to organise photo libraries
      "raycast" # Control your tools with a few keystrokes
      "setapp" # Collection of apps available by subscription
      "skim" # PDF reader and note-taking application
      "soundsource" # Sound and audio controller
      "spamsieve" # Spam filtering extension for e-mail clients
      "steam" # Video game digital distribution service
      "supacode" # Worktree coding agents command center (macOS)
      "superwhisper" # AI-powered dictation tool
      "syncthing-app" # Real time file synchronisation software
      "tailscale-app" # WireGuard-based VPN client
      "texstudio" # LaTeX editor
      "textsniper" # Extract text from images using OCR
      "tower" # Git client focusing on power and productivity
      "visual-studio-code"
      "vmlx"
      "winbox" # Administration tool for MikroTik RouterOS
      "zed" # Replacing nix flake due to https://github.com/zed-industries/zed/issues/59250
    ];

    # Mac App Store apps (requires signed into App Store)
    # Find app IDs: mas search <name> or https://github.com/mas-cli/mas
    # Format: "App Name" = app_id;
    masApps = {
      "1Password for Safari" = 1569813296;
      "Acorn" = 6737921844;
      "Amphetamine" = 937984704;
      "Auto HD FPS for YouTube" = 1546729687;
      "AutoMounter" = 1160435653;
      "BookShelves" = 6756848973;
      "Broadcasts" = 1469995354;
      "Clean Links" = 6747395062;
      "Code Peek+" = 6760186407;
      "Compressor" = 6746516157;
      "Current" = 6758530974;
      "Developer" = 640199958;
      "Drafts" = 1435957248;
      "Dropover" = 1355679052;
      "Due" = 524373870;
      "Fantastical" = 975937182;
      "Final Cut Pro" = 1631624924;
      "Flix Fixer" = 6743055061;
      "Front and Center" = 1493996622;
      "Goban" = 646372172;
      "Gomoku" = 457851462;
      "Hyperduck" = 6444667067;
      "HyperSpace" = 6739505345;
      "Ivory" = 6444602274;
      "John's Background Switcher" = 907640277;
      "keymapp" = 6472865291;
      "Keynote" = 361285480;
      "LanguageTool" = 1534275760;
      "Logic Pro" = 1615087040;
      "MainStage" = 6746637089;
      "Marked 3" = 6747497179;
      "Mela" = 1568924476;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Word" = 462054704;
      "Motion" = 6746637149;
      "NepTunes" = 1006739057;
      "Numbers" = 361304891;
      "Obsidian Web Clipper" = 6720708363;
      "OneDrive" = 823766827;
      "Pages" = 361309726;
      "Pastel" = 413897608;
      "PastePal" = 1503446680;
      "Photomator" = 1444636541;
      "Pixelmator Pro" = 6746662575;
      "Raycast Companion" = 6738274497;
      "Save to Raindrop.io" = 1549370672;
      "Simple Comic" = 1497435571;
      "Sink It" = 6449873635;
      "Steam Link" = 1246969117;
      "StopTheMadness Pro" = 6471380298;
      "Swift Playground" = 1496833156;
      "Things" = 904280696;
      "Tidyshot" = 6758950886;
      "Transmit" = 1436522307;
      "uBlock Origin Lite" = 6745342698;
      "Velja" = 1607635845;
      "Windows App" = 1295203466;
      "WireGuard" = 1451685025;
      "Kagi for Safari" = 1622835804;
      # "Xcode" = 497799835;
    };
  };

  # (Re)create the brew autoupdate LaunchAgent plist on every darwin-rebuild switch.
  # All logic lives in scripts/configure-brew-autoupdate.sh; this binding only
  # passes the configured interval through as an env var and invokes the script.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    AUTOUPDATE_INTERVAL=${lib.escapeShellArg (toString autoupdateInterval)} \
      ${lib.getExe configureBrewAutoupdateScript} || true
  '';
}
