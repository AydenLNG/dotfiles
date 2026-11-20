#!/usr/bin/env bash
# gamemode.sh: toggle game mode (Mod+G).
#   On:  blur, shadows and animations off for maximum FPS, notifications silenced
#        (Do Not Disturb), rocket icon in the bar.
#   Off: everything back exactly as rice.lua sets it.
# The state is a file, so game mode also survives a config reload
# (rice.lua checks for it), e.g. when the wallpaper changes.

STATE="${XDG_CACHE_HOME:-$HOME/.cache}/rice/gamemode"
mkdir -p "$(dirname "$STATE")"

refresh_bar() { pkill -RTMIN+9 waybar 2>/dev/null; }

# At login: game mode never carries over from the last session.
if [[ "${1:-}" == "--reset" ]]; then
    if [[ -f "$STATE" ]]; then rm -f "$STATE"; hyprctl reload >/dev/null; fi
    exit 0
fi

if [[ -f "$STATE" ]]; then
    rm -f "$STATE"
    hyprctl reload >/dev/null                      # restores rice.lua's look
    swaync-client --dnd-off >/dev/null 2>&1
    notify-send -a "Game mode" "Game mode off" "Blur, shadows and animations are back."
else
    touch "$STATE"
    notify-send -a "Game mode" "Game mode on" "Blur, shadows and animations off. Notifications silenced."
    # Lua config (Hyprland 0.57+), with the older keyword form as a fallback.
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } }, animations = { enabled = false } })' >/dev/null 2>&1 \
        || hyprctl --batch "keyword decoration:blur:enabled 0; keyword decoration:shadow:enabled 0; keyword animations:enabled 0" >/dev/null 2>&1
    sleep 0.5                                       # let the notification show before silencing
    swaync-client --dnd-on >/dev/null 2>&1
fi
refresh_bar
