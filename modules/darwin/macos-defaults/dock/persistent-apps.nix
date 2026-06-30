# Dock Persistent Apps
#
# Apps appear in the Dock in this exact order.
# Manual Dock changes WILL BE OVERWRITTEN on rebuild.
#
# App locations:
#   - System apps: /System/Applications/
#   - Nix system packages: /Applications/Nix Apps/
#   - Home Manager apps (copyApps): ~/Applications/Home Manager Apps/
#   - Manual installs: /Applications/
#   - User apps: ~/Applications/
#
# NOTE: TCC-sensitive apps (Ghostty, VS Code, Discord) use copyApps (migrated
# from mac-app-util trampolines) for stable paths that persist macOS TCC
# permissions across darwin-rebuild.

_:

let
  userConfig = import ../../../lib/user-config.nix;
  inherit (userConfig.user) homeDir;
in
{
  system.defaults.dock = {
    # ========================================================================
    # Left side of Dock (before separator) - Main apps
    # ========================================================================
    persistent-apps = [
      "/System/Applications/Apps.app"
      "/Applications/Safari.app"
      "/Applications/Helium.app"
      "/Applications/Google Chrome.app"
      "/System/Applications/Mail.app"
      "/System/Applications/Messages.app"
      "/System/Applications/Calendar.app"
      "/System/Applications/Reminders.app"
      "/System/Applications/Photos.app"
      "/System/Applications/Music.app"
      "/System/Applications/TV.app"
      "/System/Applications/News.app"
      "/System/Applications/App Store.app"
      "/System/Applications/System Settings.app"
      "/System/Applications/Preview.app"

      # Development & Tools
      "/Applications/Zed.app"
      "/Applications/Ghostty.app"
      "/Applications/Home Manager Apps/Discord.app" # nixpkgs, copyApps for TCC stability

      # AI Assistants
      "/Applications/Claude.app" # Anthropic Claude desktop app (homebrew cask)

      # NOTE: Ollama runs headless via LaunchAgent, no dock icon needed.
      # NOTE: Additional AI tools (ChatGPT, Cursor) can be found in
      # ~/Applications/Home Manager Apps/, but they are not pinned to the Dock.
      # NOTE: RapidAPI, Postman, and Bitwarden removed from dock per #438
    ];

    # ========================================================================
    # Right side of Dock (after separator) - Folders & utilities
    # ========================================================================
    # No persistent folders configured.
    # Recent apps will appear here if show-recents is enabled.
    persistent-others = [
      {
        folder = {
          path = "${homeDir}/Downloads";
          showas = "fan";
          displayas = "folder";
          arrangement = "date-modified";
        };
      }
    ];
  };
}
