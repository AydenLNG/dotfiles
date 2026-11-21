#!/usr/bin/env bash
# media-status.sh: play / pause button for the bar's media drawer.
# Button style, like YouTube or Spotify: shows pause while playing, play while paused.
# Runs continuously; playerctl prints a line every time the status changes.

PLAY=$''
PAUSE=$''

emit() {
    case "$1" in
        Playing) printf '{"text": "%s", "tooltip": "Pause", "class": "playing"}\n' "$PAUSE" ;;
        Paused)  printf '{"text": "%s", "tooltip": "Play", "class": "paused"}\n' "$PLAY" ;;
        *)       printf '{"text": "%s", "tooltip": "Nothing playing", "class": "stopped"}\n' "$PLAY" ;;
    esac
}

emit "$(playerctl status 2>/dev/null)"
playerctl --follow status 2>/dev/null | while read -r status; do
    emit "$status"
done
