{ pkgs, nvf, catppuccin-bat, catppuccin, ... }:

let
  userDefs    = import ../../../users.nix;
  primaryUser = userDefs.primaryUser;
in
{
  imports = [
    ../common-darwin.nix
    ../../../modules/darwin/certbot.nix
    ../../../modules/common/certbot-secrets.nix
  ];

  networking.hostName    = "codex";
  networking.computerName = "codex";

  # Darwin-specific system packages
  environment.systemPackages = [ pkgs.dockutil ];

  # nix-homebrew — manages the Homebrew installation itself
  nix-homebrew = {
    enable        = true;
    enableRosetta = true;    # x86 bottles on Apple Silicon via Rosetta 2
    user          = primaryUser;
    autoMigrate   = true;    # adopt an existing /opt/homebrew install
  };

  # Homebrew — managed formulae and casks
  homebrew = {
    enable         = true;
    onActivation   = {
      autoUpdate = false;       # don't slow down `darwin-rebuild switch`
      cleanup    = "uninstall"; # remove formulae/casks no longer in this list
    };
    brews = [
      "mas"          # Mac App Store CLI
      "pinentry-mac" # GPG pinentry with macOS Keychain / Touch ID support
    ];
    casks = [
      # Development Tools
      "claude"            # Anthropic's official Claude AI desktop app
      "visual-studio-code"
      "zed"               # Replacing nix flake due to https://github.com/zed-industries/zed/issues/59250
      "tower"             # Git client focusing on power and productivity
      "kaleidoscope"      # Spot and merge differences in text and image files or folders
      "lm-studio"
      "hex-fiend"         # Hex editor focussing on speed
      "jetbrains-toolbox" # JetBrains tools manager
      "orbstack"          # Fast, light Docker and Linux VM manager
      "plistedit-pro"     # Property list and JSON editor
      "vmlx"
      # Communication Tools
      "discord"           # Voice and text chat software
      # "slack"    — moved to pkgs.slack in home/alberth/default.nix
      # "telegram" — moved to pkgs.telegram-desktop in home/alberth/default.nix
      # "zoom"     — moved to pkgs.zoom-us in home/alberth/default.nix
      # Utility Tools
      "syncthing-app"              # Real time file synchronisation software
      "airfoil"                    # Sends audio from computer to outputs
      "arq"                        # Multi-cloud backup application
      "audio-hijack"               # Records audio from any application
      "automounterhelper"          # Helper for AutoMounter to mount shares to custom locations
      "betterdiscord-installer"    # Installer for BetterDiscord
      "betterdisplay"              # Display management tool
      "bettermouse"
      "bettertouchtool"            # Customise touchpad behavior
      "cleanshot"                  # Screen capturing tool
      "coherence-x"                # GUI for managing CrossOver/Wine bottles
      "crossover"                  # Tool to run Windows software
      "elgato-capture-device-utility" # Update and configure Elgato Capture devices
      "elgato-stream-deck"         # Assign keys, and then decorate and label them
      "elgato-studio"              # Capture and manage Elgato devices for content creation
      "elgato-wave-link"           # Mixer software for Elgato Wave audio devices
      "farrago"
      "piezo"
      "fission"                    # Audio editor
      "focusrite-control-2"        # Focusrite interface controller for devices of the 4th generation and newer
      "ghostty"                    # Terminal emulator that uses platform-native UI and GPU acceleration
      "hazel"                      # Automated organisation
      "keyboard-maestro"           # Automation software
      "latest"                     # Utility that shows the latest app updates
      "lingon-x"                   # GUI for creating and managing launchd jobs
      "loopback"                   # Loopback audio driver
      "mactex"                     # Full TeX Live distribution with GUI applications
      "obs"                        # Open-source software for live streaming and screen recording
      "setapp"                     # Collection of apps available by subscription
      "skim"                       # PDF reader and note-taking application
      "soundsource"                # Sound and audio controller
      "superwhisper"               # AI-powered dictation tool
      "textsniper"                 # Extract text from images using OCR
      "texstudio"                  # LaTeX editor
      "winbox"                     # Administration tool for MikroTik RouterOS
      # Entertainment Tools
      "steam"     # Video game digital distribution service
      # "vlc"     — moved to pkgs.vlc in home/alberth/default.nix
      "iina"      # Free and open-source media player
      # "spotify" — moved to pkgs.spotify in home/alberth/default.nix
      # Productivity Tools
      "raycast"   # Control your tools with a few keystrokes
      "obsidian"  # Knowledge base that works on top of a local folder of plain text Markdown files
      # Graphics
      # "inkscape" — moved to pkgs.inkscape in modules/common/packages.nix
      "pixelsnap"    # Screen measuring tool
      "powerphotos"  # Tool to organise photo libraries
      # Security
      "gpg-suite@nightly"  # Tools to protect your emails and files
      "little-snitch"      # Host-based application firewall
      "spamsieve"          # Spam filtering extension for e-mail clients
      "tailscale-app"      # WireGuard-based VPN client
      # Browsers
      "google-chrome"
      "helium-browser"  # Chromium-based web browser
      # Fonts — those with nixpkgs equivalents moved to home/alberth/default.nix
      # "font-anonymous-pro"              — pkgs.anonymousPro
      # "font-dejavu-sans-mono-nerd-font" — pkgs.nerd-fonts.dejavu-sans-mono
      # "font-inconsolata"                — pkgs.inconsolata
      # "font-inconsolata-go-nerd-font"   — pkgs.nerd-fonts.inconsolata-go
      # "font-iosevka"                    — pkgs.iosevka
      # "font-jetbrains-mono"             — pkgs.jetbrains-mono
      # "font-jetbrains-mono-nerd-font"   — pkgs.nerd-fonts.jetbrains-mono
      # "font-liberation"                 — pkgs.liberation_ttf
      "font-sf-mono-nerd-font-ligaturized" # no nixpkgs equivalent
      "font-tengwar-telcontar"
      "font-zed-mono"
      "font-zed-mono-nerd-font"
      "font-zed-sans"
    ];
  };

  # Merge codex home overlay on top of the base imported by common-darwin.nix
  home-manager.users.${primaryUser} = { imports = [ ../../../home/alberth/codex.nix ]; };

  nixie.certbot = {
    enable          = true;
    domains         = [ "home.matos.cc" ];
    syncthingDeploy = true;  # copy renewed cert to syncthing and restart on renewal
  };
}
