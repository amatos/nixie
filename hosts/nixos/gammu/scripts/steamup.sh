#!/usr/bin/env bash
#
# steamup.sh — start a headless gamescope + Steam Big Picture session at 4K
# for Steam Remote Play. No physical or virtual display is required; the
# gamescope `headless` backend creates none.
#
# Usage: steamup.sh
#
# Launches detached via setsid so the session survives the SSH connection
# ending. Connect from another device already signed into the same Steam
# account using Steam's built-in "Remote Play".
#
# To stop: pkill -f 'gamescope --backend headless'
#
# Note: if gamescope fails to start in this mode, it may be hitting
# https://github.com/NixOS/nixpkgs/issues/351516 (bubblewrap failing to hand
# CAP_SYS_NICE to Steam) — try setting programs.gamescope.capSysNice = false
# in the host config and rebuilding.

set -uo pipefail

readonly WIDTH=3840
readonly HEIGHT=2160
readonly LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/steamup.log"

if pgrep -f "gamescope --backend headless" >/dev/null 2>&1; then
    echo "steamup: a headless gamescope session is already running" >&2
    exit 1
fi

echo "steamup: starting headless gamescope (${WIDTH}x${HEIGHT}) — logging to ${LOG_FILE}"

setsid gamescope \
    -W "$WIDTH" -H "$HEIGHT" \
    -w "$WIDTH" -h "$HEIGHT" \
    --backend headless \
    --steam \
    -- steam -tenfoot -pipewire-dmabuf \
    >"$LOG_FILE" 2>&1 </dev/null &

disown

echo "steamup: launched (pid $!)"
