#!/usr/bin/env bash
# workspace-cycle.sh: Alt+Tab / Alt+Shift+Tab. Goes through workspaces 1-5 in
# order, empty ones included, wrapping 5 -> 1 (and 1 -> 5 going back).
# Usage: workspace-cycle.sh next | prev

COUNT=5
# Read the current workspace from Hyprland's JSON output (stable format),
# falling back to the plain text output.
current="$(hyprctl activeworkspace -j 2>/dev/null | grep -o '"id": *-\?[0-9]*' | head -1 | grep -o -- '-\?[0-9]*$')"
[[ "$current" =~ ^[0-9]+$ ]] || \
    current="$(hyprctl activeworkspace 2>/dev/null | grep -oi 'workspace id -\?[0-9]*' | head -1 | grep -o -- '-\?[0-9]*$')"
[[ "$current" =~ ^[0-9]+$ ]] || current=1
(( current > COUNT )) && current=$COUNT

if [[ "${1:-next}" == "prev" ]]; then
    target=$(( (current + COUNT - 2) % COUNT + 1 ))
else
    target=$(( current % COUNT + 1 ))
fi

hyprctl dispatch "hl.dsp.focus({ workspace = $target })" >/dev/null
