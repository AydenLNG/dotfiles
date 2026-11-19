#!/usr/bin/env bash
# screenshot.sh: take a screenshot, save it to ~/Pictures/Screenshots and copy
# it to the clipboard.
#   screenshot.sh area    drag to select (Print)
#   screenshot.sh full    whole screen   (Shift+Print)

set -uo pipefail
DIR="$HOME/Pictures/Screenshots"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S_%3N).png"
mkdir -p "$DIR"

# Selection box colours from the current palette (falls back to defaults).
read -r accent bg < <(python3 - <<'PY' 2>/dev/null || echo "86aaec 14151e"
import json, os
p = json.load(open(os.path.expanduser("~/.cache/rice/palette.json")))
print(p["accent"], p["bg"])
PY
)

case "${1:-area}" in
    area)
        region="$(slurp -b "${bg}66" -c "${accent}ff" -w 2)" || exit 0   # Esc cancels
        grim -g "$region" "$FILE" ;;
    full)
        grim "$FILE" ;;
    *)  echo "usage: screenshot.sh area|full"; exit 1 ;;
esac || { notify-send "Screenshot" "Failed"; exit 1; }

wl-copy --type image/png < "$FILE"
notify-send -a screenshot -i "$FILE" "Screenshot saved" "${FILE/#"$HOME"/\~} (also copied)"
