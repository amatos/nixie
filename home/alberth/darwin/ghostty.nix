# Ghostty settings — shared across all darwin hosts.
# Migrated from ~/Library/Application Support/com.mitchellh.ghostty/config.
#
# command is set per-host (codex.nix / darwintron.nix) to the nix-managed
# fish path, overriding the default shell lookup.
_:

{
  programs.ghostty.settings = {
    # ── Font ──────────────────────────────────────────────────────────────────
    font-family = "JetBrainsMono Nerd Font";
    font-size = 14;
    font-feature = "-calt"; # disable programming ligatures

    # ── Theme / colors ────────────────────────────────────────────────────────
    # Adaptive Dracula — switches between light and dark with the OS theme.
    # Both variants are bundled with Ghostty; run `ghostty +list-themes` to explore.
    theme = "light:dracula,dark:dracula";
    background-opacity = 0.90;
    background-blur = true; # blur the background when opacity < 1

    # ── Window ────────────────────────────────────────────────────────────────
    # "srgb" | "display-p3" (macOS only)
    window-colorspace = "srgb";

    # ── macOS ─────────────────────────────────────────────────────────────────
    macos-icon = "xray";
    macos-auto-secure-input = true;
    macos-secure-input-indication = true;

    # ── Shell integration ─────────────────────────────────────────────────────
    shell-integration-features = "sudo,title,ssh-env,ssh-terminfo,path";

    # ── Clipboard ─────────────────────────────────────────────────────────────
    clipboard-trim-trailing-spaces = true;
    clipboard-paste-protection = true;
    # "false" | "true" | "clipboard"
    copy-on-select = "clipboard";

    # ── Behaviour ─────────────────────────────────────────────────────────────
    confirm-close-surface = false;
    link-url = true;
    mouse-shift-capture = true;
    # "never" | "unfocused" | "always"
    notify-on-command-finish = "unfocused";
    quit-after-last-window-closed = false;
  };
}
