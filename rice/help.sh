#!/usr/bin/env bash
# help.sh: troubleshooting notes (Mod+Shift+N). Pick a topic, read it in a
# floating kitty window. The notes live in ~/.config/rice/troubleshooting.md.

NOTES="$HOME/.config/rice/troubleshooting.md"
[[ -f "$NOTES" ]] || { notify-send "Troubleshooting" "Notes file not found: $NOTES"; exit 1; }

if pgrep -x rofi >/dev/null; then pkill -x rofi; exit 0; fi

topics="$(grep '^## ' "$NOTES" | sed 's/^## //')"
choice="$( { echo "All notes"; echo "$topics"; } \
    | rofi -dmenu -i -p "help" -theme "$HOME/.config/rice/menu.rasi" -theme-str 'window { width: 560px; } listview { lines: 14; }')" || exit 0

tmp="$(mktemp -t rice-help.XXXXXX)"
if [[ "$choice" == "All notes" ]]; then
    cp "$NOTES" "$tmp"
else
    # Print the chosen section: from its heading to the next "## " heading.
    awk -v t="## $choice" '$0 == t {on=1; print; next} /^## / {on=0} on' "$NOTES" > "$tmp"
fi

# Read with less if it is installed; otherwise print it and wait for Enter.
if command -v less >/dev/null; then
    viewer="less -R '$tmp'"
else
    viewer="cat '$tmp'; echo; read -rp 'Press Enter to close'"
fi
setsid -f kitty --class rice-help --title "Troubleshooting" \
    bash -c "$viewer; rm -f '$tmp'" >/dev/null 2>&1
