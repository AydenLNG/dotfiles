#!/usr/bin/env bash
# osd.sh: on-screen level after pressing the volume or brightness keys.
#   osd.sh volume | osd.sh brightness
# Hyprland's own key binds change the level; rice.lua also runs this script on
# the same keys, so it only READS the new level and shows it. It reuses one
# notification (replace id), so holding the key updates a single popup instead
# of stacking many. Transient: it never lands in the notification history.

ID_FILE="${XDG_RUNTIME_DIR:-/tmp}/rice-osd-id"
sleep 0.08                                     # let the key bind apply the change first

case "${1:-}" in
    volume)
        out="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)"   # Volume: 0.76 [MUTED]
        level="$(awk '{printf "%d", $2 * 100 + 0.5}' <<<"$out")"
        if [[ "$out" == *MUTED* ]]; then
            title="Muted"; icon="audio-volume-muted"
        else
            title="Volume ${level}%"
            if   (( level == 0 ));  then icon="audio-volume-muted"
            elif (( level < 34 ));  then icon="audio-volume-low"
            elif (( level < 67 ));  then icon="audio-volume-medium"
            else                         icon="audio-volume-high"
            fi
        fi ;;
    brightness)
        level="$(brightnessctl -m -c backlight info 2>/dev/null | cut -d, -f4 | tr -d '%')"
        [[ "$level" =~ ^[0-9]+$ ]] || exit 0    # no laptop screen: nothing to show
        title="Brightness ${level}%"; icon="display-brightness" ;;
    *) exit 1 ;;
esac
[[ "$level" =~ ^[0-9]+$ ]] || exit 0

replace=()
old="$(cat "$ID_FILE" 2>/dev/null)"
[[ "$old" =~ ^[0-9]+$ ]] && replace=(-r "$old")

id="$(notify-send -e -p "${replace[@]}" -t 1200 -a "osd" -i "$icon" \
      -h "int:value:$level" -h "string:x-canonical-private-synchronous:rice-osd" \
      "$title" 2>/dev/null)"
[[ "$id" =~ ^[0-9]+$ ]] && echo "$id" > "$ID_FILE"
