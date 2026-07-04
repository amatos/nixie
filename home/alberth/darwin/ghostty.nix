# Ghostty settings — shared across all darwin hosts.
# Migrated from ~/Library/Application Support/com.mitchellh.ghostty/config.
#
# command is left unset; Ghostty inherits the login shell from the system.
_:

{
  programs.ghostty.settings = {
    # ── Font ──────────────────────────────────────────────────────────────────
    # font-family is set by stylix; font-size is explicit here because stylix's
    # size scaling produces a non-integer value for ghostty.
    font-size = 14;
    font-feature = "-calt"; # disable programming ligatures

    # ── Transparency ─────────────────────────────────────────────────────────
    # Terminal colors are set by stylix (home/alberth/common/stylix.nix).
    background-opacity = 0.90;
    background-blur = true;

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
