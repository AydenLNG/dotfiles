#!/usr/bin/env bash
# weather.sh: weather for the waybar module, for a location YOU set.
#
# Privacy: this never detects your location (no GPS, no IP lookup).
# It only asks wttr.in for the place written in ~/.config/rice/weather.conf.
# Like any website, wttr.in can still see the IP address the request comes from.
#
# Output is JSON for waybar: {"text": "...", "tooltip": "..."}

CONF="$HOME/.config/rice/weather.conf"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rice/weather.json"

LOCATION=""
UNITS="m"                                   # m = Celsius, u = Fahrenheit
# shellcheck source=/dev/null
[[ -f "$CONF" ]] && source "$CONF"

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\t'/ }"
    printf '%s' "$s"
}

# No location set: print nothing, waybar hides the module.
if [[ -z "$LOCATION" ]]; then
    printf '{"text": "", "tooltip": ""}\n'
    exit 0
fi

place="${LOCATION// /+}"
# %c icon | %t temperature | %C condition | %f feels like | %h humidity | %w wind
raw="$(curl -fsS --max-time 10 \
    "https://wttr.in/${place}?format=%c|%t|%C|%f|%h|%w&${UNITS}" 2>/dev/null)"

if [[ -z "$raw" || "$raw" != *"|"* || "$raw" == *"Unknown location"* ]]; then
    # Offline or service down: show the last result if there is one.
    if [[ -f "$CACHE" ]]; then cat "$CACHE"; else printf '{"text": "", "tooltip": "Weather unavailable"}\n'; fi
    exit 0
fi

IFS='|' read -r icon temp cond feels humid wind <<< "$raw"
icon="$(printf '%s' "$icon" | tr -d '[:space:]')"
temp="${temp#+}"

text="$icon ${temp}"
tooltip="$LOCATION: $cond"$'\n'"Feels like ${feels#+}"$'\n'"Humidity $humid"$'\n'"Wind $wind"

out="$(printf '{"text": "%s", "tooltip": "%s"}' "$(json_escape "$text")" "$(json_escape "$tooltip")")"
mkdir -p "$(dirname "$CACHE")"
printf '%s\n' "$out" | tee "$CACHE"
