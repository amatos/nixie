# Ghostty shared settings — explicit defaults for all darwin hosts.
# Values match Ghostty's built-in defaults (source: src/config/Config.zig).
# Uncomment and modify any line to customize; commented lines are available
# options that are null / unset by default.
#
# Note: background, foreground, and palette colors are managed by
# catppuccin.ghostty — do not set them here.
{ ... }:

{
  programs.ghostty.settings = {
    # ── Font ──────────────────────────────────────────────────────────────────
    # font-family = "";             # e.g. "Hack Nerd Font"; repeatable for fallbacks
    # font-family-bold = "";
    # font-family-italic = "";
    # font-family-bold-italic = "";
    # font-size = 13;               # points (macOS default: 13, Linux: 12)
    # font-feature = "";            # e.g. "-calt" to disable ligatures; repeatable
    font-thicken = false; # macOS only: draw fonts with a thicker stroke
    # font-thicken-strength = 255;  # 0–255; only applies when font-thicken = true

    # ── Color blending ────────────────────────────────────────────────────────
    # macOS default is "native"; Linux default is "linear-corrected".
    # "native" | "linear" | "linear-corrected"
    alpha-blending = "native";

    # ── Text rendering ────────────────────────────────────────────────────────
    # "unicode" | "legacy"
    grapheme-width-method = "unicode";

    # Minimum WCAG 2.0 contrast ratio between fg and bg. 1 = no enforcement.
    minimum-contrast = 1;

    # ── Cursor ────────────────────────────────────────────────────────────────
    # "block" | "bar" | "underline" | "block_hollow"
    cursor-style = "block";
    # cursor-style-blink is unset (null) by default — Ghostty respects DEC mode 12.
    # Set to true or false to override and ignore DEC mode 12.
    # cursor-style-blink = true;
    cursor-opacity = 1.0;
    cursor-click-to-move = true; # move cursor at prompt by clicking
    # cursor-color = "";            # e.g. "#FF0000" or "cell-foreground"
    # cursor-text = "";             # text color under cursor

    # ── Mouse ─────────────────────────────────────────────────────────────────
    mouse-hide-while-typing = false;
    mouse-reporting = true;
    # "false" | "true" | "always" | "never"
    mouse-shift-capture = false;

    # ── Selection ─────────────────────────────────────────────────────────────
    selection-clear-on-typing = true;
    selection-clear-on-copy = false;
    # selection-foreground = "";    # e.g. "#000000" or "cell-foreground"
    # selection-background = "";

    # ── Scrollback ────────────────────────────────────────────────────────────
    scrollback-limit = 10000000; # bytes per surface (10 MB); increase for more history
    # "system" | "never"
    scrollbar = "system";

    # Scroll to bottom on: "keystroke" (default on), "output" (default off).
    # Format: comma-separated flags; prefix with "no-" to disable.
    scroll-to-bottom = "keystroke";

    # ── Background ────────────────────────────────────────────────────────────
    background-opacity = 1.0; # 0.0–1.0; values < 1 enable transparency
    background-opacity-cells = false; # apply opacity to cells with explicit bg color
    background-blur = false; # blur when opacity < 1; true = intensity 20; or integer

    # ── Background image ──────────────────────────────────────────────────────
    # background-image = "";        # absolute path to PNG or JPEG
    background-image-opacity = 1.0;
    # "top-left" | "top-center" | "top-right" | "center-left" | "center" |
    # "center-right" | "bottom-left" | "bottom-center" | "bottom-right"
    background-image-position = "center";
    # "contain" | "cover" | "stretch" | "none"
    background-image-fit = "contain";
    background-image-repeat = false;

    # ── Splits ────────────────────────────────────────────────────────────────
    unfocused-split-opacity = 0.7; # 0.15–1.0; 1.0 disables the dimming effect
    # unfocused-split-fill = "";    # color of the dim overlay; defaults to background
    # split-divider-color = "";     # color of the split border

    # ── Links ─────────────────────────────────────────────────────────────────
    link-url = true; # open URLs with ctrl/cmd + click
    # "true" | "false" | "osc8"
    link-previews = true;

    # ── Window size & layout ──────────────────────────────────────────────────
    window-padding-x = 2; # points; left and right padding
    window-padding-y = 2; # points; top and bottom padding
    # false | true | "equal"
    window-padding-balance = false;
    # "background" | "extend" | "extend-always"
    window-padding-color = "background";
    # window-height = 0;            # grid rows; 0 = runtime default
    # window-width = 0;             # grid columns; 0 = runtime default
    # window-position-x = null;     # pixels from top-left of primary monitor (macOS)
    # window-position-y = null;

    # ── Window behaviour ──────────────────────────────────────────────────────
    maximize = false;
    fullscreen = false; # false | true | "non-native" | "non-native-visible-menu" |
    # "non-native-padded-notch" (macOS only)
    # "none" | "auto" | "client" | "server"
    window-decoration = "auto";
    # "auto" | "system" | "light" | "dark" | "ghostty"
    window-theme = "auto";
    # "srgb" | "display-p3" (macOS only)
    window-colorspace = "srgb";
    window-vsync = true; # sync redraws to screen refresh rate (macOS only)
    window-save-state = "default"; # "default" | "never" | "always" (macOS only)
    window-step-resize = false; # resize in discrete cell increments (macOS only)
    # title = null;                 # force a fixed window/tab title

    # ── Inheritance ───────────────────────────────────────────────────────────
    window-inherit-working-directory = true;
    window-inherit-font-size = true;
    tab-inherit-working-directory = true;
    split-inherit-working-directory = true;

    # ── Shell integration ─────────────────────────────────────────────────────
    # "detect" | "none" | "bash" | "fish" | "zsh"
    # shell-integration = "detect";
    # shell-integration-features = "cursor,sudo,title"; # comma-separated

    # ── Notifications ─────────────────────────────────────────────────────────
    # "never" | "unfocused" | "always"
    notify-on-command-finish = "never";

    # ── Miscellaneous ─────────────────────────────────────────────────────────
    wait-after-command = false; # keep window open after command exits (debug)
    abnormal-command-exit-runtime = 250; # ms; 0 disables the warning

    # ── Palette ───────────────────────────────────────────────────────────────
    # palette colors are managed by catppuccin.ghostty — do not set here.
    palette-generate = false; # auto-generate 256-color palette from base 16
    palette-harmonious = false; # invert generated palette (requires palette-generate)
  };
}
