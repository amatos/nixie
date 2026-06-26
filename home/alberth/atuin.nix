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
      # Disable up-arrow binding — use shell native history for ↑; Ctrl-R opens atuin
      up_key_binding = false;
      filter_mode = "global";
      style = "compact";
    };
  };
}
