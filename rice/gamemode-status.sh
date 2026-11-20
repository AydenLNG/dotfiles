#!/usr/bin/env bash
# gamemode-status.sh: bar indicator for game mode. Prints nothing when off,
# which hides the module. Refreshed instantly by gamemode.sh (signal 9).
STATE="${XDG_CACHE_HOME:-$HOME/.cache}/rice/gamemode"
if [[ -f "$STATE" ]]; then
    printf '{"text": "  game", "tooltip": "Game mode on. Click or Mod+G to turn off.", "class": "on"}\n'
fi
