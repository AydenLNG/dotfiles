# ~/.config/kitty/auto_font.py
# kitty watcher: scales the font with the window width, so a full-screen
# terminal gets bigger text and a small tiled one gets smaller text.
# Loaded by the "watcher auto_font.py" line in kitty.conf.
# Tune the numbers below. Ctrl+Shift+Equal / Minus still work for a manual
# change, until the window is next resized.

from typing import Any

MIN_SIZE = 10.0         # smallest font size (points)
MAX_SIZE = 16.0         # largest font size
BASE = 8.0              # size at zero width
PIXELS_PER_POINT = 240  # every this many pixels of width adds 1 point


def target_size(width_px: int) -> float:
    size = BASE + width_px / PIXELS_PER_POINT
    size = round(size * 2) / 2          # half-point steps, avoids constant tiny changes
    return max(MIN_SIZE, min(MAX_SIZE, size))


def on_resize(boss: Any, window: Any, data: dict[str, Any]) -> None:
    geo = data["new_geometry"]
    width = geo.right - geo.left
    if width <= 0:
        return
    try:
        from kitty.fast_data_types import os_window_font_size
        current = os_window_font_size(window.os_window_id)
        wanted = target_size(width)
        if current and abs(current - wanted) >= 0.5:
            # Changing the font keeps the window's pixel width the same, so the
            # next resize event computes the same size and nothing loops.
            boss._change_font_size({window.os_window_id: wanted})
    except Exception as err:   # never break the terminal over a font size
        print("auto_font:", err)
