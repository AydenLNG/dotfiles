#!/usr/bin/env bash
# gpu.sh: GPU usage for waybar (AMD cards, read from the kernel; no extra tools).
# Prints nothing on machines without an AMD GPU, which hides the module.

for dev in /sys/class/drm/card*/device; do
    [[ -r "$dev/gpu_busy_percent" ]] || continue
    busy="$(cat "$dev/gpu_busy_percent" 2>/dev/null)" || continue
    used="$(cat "$dev/mem_info_vram_used" 2>/dev/null || echo 0)"
    total="$(cat "$dev/mem_info_vram_total" 2>/dev/null || echo 0)"
    tip="GPU busy ${busy}%"
    if (( total > 0 )); then
        tip+="\\nVRAM $(( used / 1048576 )) / $(( total / 1048576 )) MiB"
    fi
    printf '{"text": "  %s%%", "tooltip": "%s"}\n' "$busy" "$tip"
    exit 0
done
