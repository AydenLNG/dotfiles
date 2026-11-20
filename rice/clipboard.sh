#!/usr/bin/env bash
# clipboard.sh: clipboard history (Mod+Shift+V). Pick an entry to copy it again.
if pgrep -x rofi >/dev/null; then pkill -x rofi; exit 0; fi
cliphist list \
    | rofi -dmenu -i -p "clipboard" -theme "$HOME/.config/rice/menu.rasi" \
           -theme-str 'window { width: 640px; } listview { lines: 12; }' \
    | cliphist decode | wl-copy
