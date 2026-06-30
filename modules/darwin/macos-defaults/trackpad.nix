# Trackpad Configuration
#
# Reference: https://nix-darwin.github.io/nix-darwin/manual/options.html

_:

{
  system.defaults.trackpad = {
    # ==========================================================================
    # Click Behavior
    # ==========================================================================

    # Tap to click
    Clicking = true;

    # Two-finger tap for right-click
    TrackpadRightClick = true;

    # ==========================================================================
    # Drag
    # ==========================================================================

    # Tap-and-hold to drag (without click)
    Dragging = false;

    # Three-finger drag
    TrackpadThreeFingerDrag = false;

    # ==========================================================================
    # Force Touch
    # ==========================================================================

    # Click pressure: 0 = light, 1 = medium, 2 = firm
    FirstClickThreshold = 1;
    SecondClickThreshold = 1;

    # Enable haptic feedback
    ActuateDetents = true;
  };

  system.defaults.NSGlobalDomain = {
    # ==========================================================================
    # Scrolling & Navigation
    # ==========================================================================

    # Natural scrolling (content moves with fingers)
    "com.apple.swipescrolldirection" = true;

    # Trackpad tracking speed (0.0 to 3.0)
    "com.apple.trackpad.scaling" = 1.0;

    # Enable secondary click (two-finger click)
    "com.apple.trackpad.enableSecondaryClick" = true;

    # Enable force click and haptic feedback
    "com.apple.trackpad.forceClick" = true;
  };
}
