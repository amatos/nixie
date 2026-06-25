# atuin — magical shell history.
# https://atuin.sh
#
# Replaces shell history (↑ / Ctrl-R) with a searchable, syncable database.
# Shell integrations for bash, zsh, and fish are enabled automatically.
{ ... }:

{
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    settings = {
      auto_sync = true;
      search_mode = "fuzzy";
      sync_address = "https://api.atuin.sh";
      sync_frequency = "5m";
      # Use the up-arrow for full history search (not just prefix match)
      filter_mode_shell_up_key_binding = "session";
      # Ctrl-R searches all history; up-arrow searches session history
      filter_mode = "global";
      style = "compact";
    };
  };
}
