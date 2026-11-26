#!/usr/bin/env bash
# battery.sh: battery for the bar (every 30 s) plus low-battery warnings.
#   Desktop (no battery): prints nothing, so the bar hides the module.
#   Laptop: icon + percentage; yellow at 20 % or less, red and blinking at 10 %
#   or less, a bolt while charging. One notification at 20 %, an urgent one at
#   10 % that stays until dismissed. Plugging in resets the warnings.
# Read-only: it only reads /sys/class/power_supply.

STATE="${XDG_CACHE_HOME:-$HOME/.cache}/rice/battery-warned"
mkdir -p "$(dirname "$STATE")"

bat=""
for b in "${RICE_POWER_DIR:-/sys/class/power_supply}"/BAT*; do
    [[ -r "$b/capacity" ]] && { bat="$b"; break; }
done
[[ -z "$bat" ]] && exit 0                      # no battery: hide

level="$(cat "$bat/capacity" 2>/dev/null)"
status="$(cat "$bat/status" 2>/dev/null)"
[[ "$level" =~ ^[0-9]+$ ]] || exit 0

# Five levels of Font Awesome battery icons, plus a bolt while charging.
if   (( level >= 90 )); then icon=$''
elif (( level >= 65 )); then icon=$''
elif (( level >= 40 )); then icon=$''
elif (( level >= 15 )); then icon=$''
else                         icon=$''
fi

class="normal"
if [[ "$status" == "Charging" || "$status" == "Full" || "$status" == "Not charging" ]]; then
    class="charging"
    [[ "$status" == "Charging" ]] && icon=$''
    rm -f "$STATE"                             # plugged in: warn again next time
elif (( level <= 10 )); then class="critical"
elif (( level <= 20 )); then class="warning"
fi

# Low-battery notifications, once per level.
if [[ "$status" == "Discharging" ]]; then
    warned="$(cat "$STATE" 2>/dev/null)"
    if (( level <= 10 )) && [[ "$warned" != 10 ]]; then
        notify-send -u critical -a "Battery" "Battery very low: ${level}%" "Plug in the charger now."
        echo 10 > "$STATE"
    elif (( level <= 20 && level > 10 )) && [[ -z "$warned" ]]; then
        notify-send -a "Battery" "Battery low: ${level}%" "Plug in the charger soon."
        echo 20 > "$STATE"
    fi
fi

# Hover text: status and time left / to full.
tip="$status"
time="$(python3 - "$bat" "$status" <<'EOF'
import sys
bat, status = sys.argv[1], sys.argv[2]
def num(n):
    try: return int(open(f"{bat}/{n}").read())
    except Exception: return 0
now, full, rate = num("energy_now"), num("energy_full"), num("power_now")
if not now: now, full, rate = num("charge_now"), num("charge_full"), num("current_now")
h = (now / rate) if rate > 0 and status == "Discharging" else ((full - now) / rate) if rate > 0 and status == "Charging" else 0
if h > 0:
    hh, mm = int(h), int(round((h - int(h)) * 60))
    print((f"{hh}h {mm:02d}m" if hh else f"{mm} min") + (" left" if status == "Discharging" else " to full"))
EOF
)"
[[ -n "$time" ]] && tip+=", $time"

printf '{"text": "%s  %s%%", "tooltip": "Battery %s%%: %s", "class": "%s", "percentage": %s}\n' \
    "$icon" "$level" "$level" "$tip" "$class" "$level"
