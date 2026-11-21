#!/usr/bin/env bash
# ping.sh: latency for the bar (every 10 s).
#   Bar text: internet ping to 1.1.1.1 (Cloudflare's public DNS address).
#   Hover:    internet and router ping. A slow router ping means Wi-Fi trouble;
#             a fine router ping with a slow internet ping means the connection.
# Uses ping; if the network blocks ping, falls back to timing a plain connection
# to 1.1.1.1. No addresses are shown, so screenshots stay clean.

TARGET="1.1.1.1"
ICON=$''

ms_ping() {   # prints whole milliseconds, or nothing
    ping -n -c 1 -W 2 "$1" 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p' | head -1 | awk '{printf "%d", $1 + 0.5}'
}

ms_connect() {   # TCP connect time to port 443, in ms
    curl -o /dev/null -s --connect-timeout 2 -w '%{time_connect}' "https://$TARGET" 2>/dev/null \
        | awk '$1 > 0 {printf "%d", $1 * 1000 + 0.5}'
}

internet="$(ms_ping "$TARGET")"
[[ -z "$internet" ]] && internet="$(ms_connect)"

router_ip="$(ip route show default 2>/dev/null | awk '{print $3; exit}')"
router=""
[[ -n "$router_ip" ]] && router="$(ms_ping "$router_ip")"
if [[ -n "$router" ]]; then router_text="$router ms"; else router_text="no reply"; fi

if [[ -z "$internet" ]]; then
    printf '{"text": "%s  --", "tooltip": "Internet: no reply\\nRouter: %s", "class": "bad"}\n' \
        "$ICON" "$router_text"
    exit 0
fi

if   (( internet < 60 ));  then class="good"
elif (( internet < 120 )); then class="ok"
else                            class="bad"
fi

printf '{"text": "%s  %s ms", "tooltip": "Internet: %s ms\\nRouter: %s", "class": "%s"}\n' \
    "$ICON" "$internet" "$internet" "$router_text" "$class"
