#!/usr/bin/env bash
# hub.sh: open or close the control centre (Super+I, or click the clock or the
# status icons in the bar). It is a Quickshell panel (rice/hub.qml) that only
# runs while it is open, so it uses no CPU or memory the rest of the time.
# Falls back to the rofi settings list if quickshell is missing.

RICE_DIR="$HOME/.config/rice"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rice"
mkdir -p "$STATE_DIR"

# Already open: close it (pressing Super+I again toggles).
if pkill -f "qs -p $RICE_DIR/hub.qml" 2>/dev/null; then exit 0; fi

if ! command -v qs >/dev/null; then
    exec "$RICE_DIR/settings-menu.sh"
fi

# First frame is filled straight away, then hub.qml refreshes every 2 s.
RICE_HUB_DATA="$(python3 "$RICE_DIR/hub-data.py" 2>/dev/null || echo '{}')" \
RICE_PALETTE="$(cat "$STATE_DIR/palette.json" 2>/dev/null || echo '{}')" \
RICE_DIR="$RICE_DIR" \
    exec qs -p "$RICE_DIR/hub.qml" >>"$STATE_DIR/hub.log" 2>&1
