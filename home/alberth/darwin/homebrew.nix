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
  ...
}:

let
  # 30 hours in seconds — brew autoupdate requires interval in seconds
  autoupdateInterval = 108000;

  configureBrewAutoupdateScript = pkgs.writeShellApplication {
    name = "configure-brew-autoupdate";
    runtimeInputs = [ ];
    text = builtins.readFile .././scripts/configure-brew-autoupdate.sh;
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
      "homebrew/autoupdate" # Background auto-update via launchd (brew autoupdate)
    ];
    brews = [
      "mas" # Mac App Store CLI
      "pinentry-mac" # GPG pinentry with macOS Keychain / Touch ID support
    ];

    casks = [
      # GUI applications (only if not available in nixpkgs)
      #
      # TCC NOTE: Homebrew casks install directly to /Applications/ (real copies,
      # not symlinks to /nix/store), so macOS TCC permissions (camera, mic, screen
      # recording) persist across darwin-rebuild. This is different from nixpkgs
      # apps which require copyApps workaround in home-manager.
      #
      # greedy = true: required for any app that ships a built-in auto-updater.
      # Without this flag, `brew upgrade` silently skips the app because Homebrew
      # assumes the app will update itself. In practice, built-in updaters are
      # unreliable (require the app to be open, can be dismissed, etc.), so greedy
      # ensures updates land deterministically via brew autoupdate.
      # NOTE: ChatGPT and Cursor are in nixpkgs - see home.packages.
      # NOTE: Antigravity and gemini-cli are in homebrew (above).

      {
        name = "1password"; # Password manager and secure digital wallet
        greedy = true;
      }
      {
        name = "1password-cli"; # 1Password command-line tool (op)
        greedy = true;
      }
      {
        name = "airfoil"; # Sends audio from computer to outputs
        greedy = true;
      }
      {
        name = "arq"; # Multi-cloud backup application
        greedy = true;
      }
      {
        name = "audio-hijack"; # Records audio from any application
        greedy = true;
      }
      {
        name = "automounterhelper"; # Helper for AutoMounter to mount shares to custom locations
        greedy = true;
      }
      {
        name = "betterdiscord-installer"; # Installer for BetterDiscord
        greedy = true;
      }
      {
        name = "betterdisplay"; # Display management tool
        greedy = true;
      }
      {
        name = "bettermouse";
        greedy = true;
      }
      {
        name = "bettertouchtool"; # Customise touchpad behavior
        greedy = true;
      }
      {
        name = "claude"; # Anthropic's official Claude AI desktop app
        greedy = true;
      }
      {
        name = "claude-code"; # Anthropic's official Claude AI CLI app
        greedy = true;
      }
      {
        name = "claudebar"; # Menu bar app for monitoring AI coding assistant usage quotas
        greedy = true;
      }
      {
        name = "cleanshot"; # Screen capturing tool
        greedy = true;
      }
      {
        name = "coherence-x"; # GUI for managing CrossOver/Wine bottles
        greedy = true;
      }
      {
        name = "crossover"; # Tool to run Windows software
        greedy = true;
      }
      {
        name = "discord"; # Voice and text chat software
        greedy = true;
      }
      {
        name = "elgato-capture-device-utility"; # Update and configure Elgato Capture devices
        greedy = true;
      }
      {
        name = "elgato-stream-deck"; # Assign keys, and then decorate and label them
        greedy = true;
      }
      {
        name = "elgato-studio"; # Capture and manage Elgato devices for content creation
        greedy = true;
      }
      {
        name = "elgato-wave-link"; # Mixer software for Elgato Wave audio devices
        greedy = true;
      }
      {
        name = "farrago";
        greedy = true;
      }
      {
        name = "fission"; # Audio editor
        greedy = true;
      }
      {
        name = "focusrite-control-2"; # Focusrite interface controller for devices of the 4th generation and newer
        greedy = true;
      }
      {
        name = "font-sf-mono-nerd-font-ligaturized"; # no nixpkgs equivalent
        greedy = true;
      }
      {
        name = "font-tengwar-telcontar";
        greedy = true;
      }
      {
        name = "font-zed-mono";
        greedy = true;
      }
      {
        name = "font-zed-mono-nerd-font";
        greedy = true;
      }
      {
        name = "font-zed-sans";
        greedy = true;
      }
      {
        name = "ghostty"; # Terminal emulator that uses platform-native UI and GPU acceleration
        greedy = true;
      }
      {
        name = "google-chrome";
        greedy = true;
      }
      {
        name = "gpg-suite@nightly"; # Tools to protect your emails and files
        greedy = true;
      }
      {
        name = "hazel"; # Automated organisation
        greedy = true;
      }
      {
        name = "helium-browser"; # Chromium-based web browser
        greedy = true;
      }
      {
        name = "hex-fiend"; # Hex editor focussing on speed
        greedy = true;
      }
      {
        name = "iina"; # Free and open-source media player
        greedy = true;
      }
      {
        name = "jetbrains-toolbox"; # JetBrains tools manager
        greedy = true;
      }
      {
        name = "kaleidoscope"; # Spot and merge differences in text and image files or folders
        greedy = true;
      }
      {
        name = "keyboard-maestro"; # Automation software
        greedy = true;
      }
      {
        name = "latest"; # Utility that shows the latest app updates
        greedy = true;
      }
      {
        name = "lingon-x"; # GUI for creating and managing launchd jobs
        greedy = true;
      }
      {
        name = "little-snitch"; # Host-based application firewall
        greedy = true;
      }
      {
        name = "lm-studio";
        greedy = true;
      }
      {
        name = "loopback"; # Loopback audio driver
        greedy = true;
      }
      {
        name = "mactex"; # Full TeX Live distribution with GUI applications
        greedy = true;
      }
      {
        name = "obs"; # Open-source software for live streaming and screen recording
        greedy = true;
      }
      {
        name = "obsidian"; # Knowledge base that works on top of a local folder of plain text Markdown files
        greedy = true;
      }
      {
        name = "orbstack";
        greedy = true;
      }
      {
        name = "piezo";
        greedy = true;
      }
      {
        name = "pixelsnap"; # Screen measuring tool
        greedy = true;
      }
      {
        name = "plistedit-pro"; # Property list and JSON editor
        greedy = true;
      }
      {
        name = "powerphotos"; # Tool to organise photo libraries
        greedy = true;
      }
      {
        name = "raycast"; # Control your tools with a few keystrokes
        greedy = true;
      }
      {
        name = "setapp"; # Collection of apps available by subscription
        greedy = true;
      }
      {
        name = "skim"; # PDF reader and note-taking application
        greedy = true;
      }
      {
        name = "soundsource"; # Sound and audio controller
        greedy = true;
      }
      {
        name = "spamsieve"; # Spam filtering extension for e-mail clients
        greedy = true;
      }
      {
        name = "steam"; # Video game digital distribution service
        greedy = true;
      }
      {
        name = "superwhisper"; # AI-powered dictation tool
        greedy = true;
      }
      {
        name = "syncthing-app"; # Real time file synchronisation software
        greedy = true;
      }
      {
        name = "tailscale-app"; # WireGuard-based VPN client
        greedy = true;
      }
      {
        name = "texstudio"; # LaTeX editor
        greedy = true;
      }
      {
        name = "textsniper"; # Extract text from images using OCR
        greedy = true;
      }
      {
        name = "tower"; # Git client focusing on power and productivity
        greedy = true;
      }
      {
        name = "visual-studio-code";
        greedy = true;
      }
      {
        name = "vmlx";
        greedy = true;
      }
      {
        name = "winbox"; # Administration tool for MikroTik RouterOS
        greedy = true;
      }
      {
        name = "zed"; # Replacing nix flake due to https://github.com/zed-industries/zed/issues/59250
        greedy = true;
      }
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
      "Ivory" = 6444602274;
      "John's Background Switcher" = 907640277;
      "keymapp" = 6472865291;
      "Keynote" = 361285480;
      "LanguageTool" = 1534275760;
      "Logic Pro" = 1615087040;
      "MainStage" = 6746637089;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Word" = 462054704;
      "Motion" = 6746637149;
      "NepTunes" = 1006739057;
      "Numbers" = 361304891;
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
      "Xcode" = 497799835;
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
