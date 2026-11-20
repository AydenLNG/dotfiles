#!/usr/bin/env python3
"""
theme-sync.py: build a colour palette from a wallpaper and apply it to the desktop.

Usage:
    theme-sync.py <image>      generate a palette from the image and apply it
    theme-sync.py --default    apply the built-in "late night" palette

What it writes (all inside your home folder, nothing system-wide):
    ~/.config/kitty/colors.conf     terminal colours + glass transparency
    ~/.config/waybar/colors.css     bar colours
    ~/.config/fuzzel/fuzzel.ini     launcher look
    ~/.config/mako/config           notification look
    ~/.config/hypr/colors.lua       window border colours
    ~/.config/cava/themes/rice      audio visualizer colours
    ~/.config/rice/colors.rasi      wallpaper picker colours
    ~/.config/gtk-3.0/colors.css    GTK 3 apps (Thunar, Blueman, ...)
    ~/.config/gtk-4.0/colors.css    GTK 4 apps (Sound settings, File Roller, ...)
    ~/.config/hypr/hyprlock.conf    lock screen
    ~/.config/imv/config            image viewer background
    /usr/local/share/rice-login/regreet.css   login screen (only if set up)
    ~/.cache/rice/palette.json      the palette, for reference

Then it reloads waybar, mako and Hyprland, and recolours terminals that are
already open. Only uses the Python standard library plus ImageMagick.
"""

import colorsys
import json
import os
import re
import shutil
import stat
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------- settings
TERMINAL_ALPHA = 0.78   # kitty background opacity (0 = invisible, 1 = solid)
PANEL_ALPHA = "d9"      # fuzzel / mako background opacity, hex 00-ff
FONT = "JetBrainsMono Nerd Font"

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "rice"
LOGIN_DIR = Path(os.environ.get("RICE_LOGIN_DIR", "/usr/local/share/rice-login"))

# Fallback palette. Colour values from the kitty theme in 1amSimp1e's
# "late night" rice (github.com/1amSimp1e/dots).
DEFAULT_PALETTE = {
    "bg": "14151e", "surface": "1f2233", "fg": "c0caf5", "muted": "6b7394",
    "accent": "86aaec", "accent2": "c296eb", "urgent": "dd6777",
    "black": "1f2233", "red": "dd6777", "green": "90ceaa", "yellow": "ecd3a0",
    "blue": "86aaec", "magenta": "c296eb", "cyan": "93cee9", "white": "cbced3",
    "bright_black": "4f5572", "bright_red": "e26c7c", "bright_green": "95d3af",
    "bright_yellow": "f1d8a5", "bright_blue": "8baff1", "bright_magenta": "c79bf0",
    "bright_cyan": "98d3ee", "bright_white": "e4e6eb",
}

# Hue (degrees) of each terminal colour before it is tinted by the wallpaper.
ANSI_HUES = {"red": 355, "green": 135, "yellow": 42, "blue": 215,
             "magenta": 285, "cyan": 185}


# ---------------------------------------------------------------- colour math
def hex_to_rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return "".join(f"{round(max(0, min(1, c)) * 255):02x}" for c in rgb)


def hls(h_deg, l, s):
    """Build a hex colour from hue (degrees), lightness, saturation (0-1)."""
    return rgb_to_hex(colorsys.hls_to_rgb((h_deg % 360) / 360, l, s))


def to_hls(hex_color):
    h, l, s = colorsys.rgb_to_hls(*hex_to_rgb(hex_color))
    return h * 360, l, s


def hue_distance(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


# ---------------------------------------------------------------- palette
def find_magick():
    for name in ("magick", "convert"):
        path = shutil.which(name)
        if path:
            return path
    sys.exit("theme-sync: ImageMagick not found (install it with: sudo pacman -S imagemagick)")


def extract_colors(image):
    """Return [(count, hex)] for the 16 most common colours of the image."""
    # -colorspace/-type/-depth force plain 8-bit RGB output, so grey or 16-bit
    # images are reported the same way as normal colour photos.
    cmd = [find_magick(), f"{image}[0]", "-resize", "200x200>", "-colors", "16",
           "-colorspace", "sRGB", "-type", "TrueColor", "-depth", "8",
           "-format", "%c", "histogram:info:-"]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if out.returncode != 0:
        sys.exit(f"theme-sync: could not read image: {out.stderr.strip()}")
    colors = []
    for line in out.stdout.splitlines():
        # Lines look like:  "  1180: (255,155,61) #FF9B3D srgb(255,155,61)"
        m = re.match(r"\s*(\d+):\s*\(([^)]*)\)", line)
        if not m:
            continue
        values = [float(v) for v in re.findall(r"[\d.]+", m.group(2))]
        if not values:
            continue
        rgb = values[:3] if len(values) >= 3 else values[:1] * 3   # grey = one value
        scale = 257 if max(rgb) > 255 else 1                        # 16-bit safety net
        colors.append((int(m.group(1)), rgb_to_hex([v / scale / 255 for v in rgb])))
    if not colors:
        sys.exit("theme-sync: no colours found in image")
    return sorted(colors, reverse=True)


def build_palette(image):
    colors = extract_colors(image)
    total = sum(c for c, _ in colors)
    info = [(count / total, *to_hls(hx)) for count, hx in colors]  # (share, h, l, s)

    # Background: the most common darker colour, pushed very dark.
    dark = [c for c in info if c[2] < 0.5] or info
    _, bg_h, _, bg_s = max(dark, key=lambda c: c[0])
    bg_s = min(bg_s, 0.35)

    # Accent: a colourful, reasonably common colour that is not near-black or near-white.
    candidates = [c for c in info if 0.15 < c[2] < 0.9 and c[3] > 0.15]
    candidates.sort(key=lambda c: c[3] * (c[0] ** 0.3), reverse=True)
    if candidates:
        acc_h, acc_s = candidates[0][1], max(0.45, min(candidates[0][3], 0.75))
    else:                       # grey/black-and-white wallpaper: calm blue-grey accent
        acc_h, acc_s = (bg_h if bg_s > 0.05 else 220), 0.30

    acc2_h = next((c[1] for c in candidates[1:] if hue_distance(c[1], acc_h) > 40),
                  acc_h + 50)

    pal = {
        "bg": hls(bg_h, 0.085, bg_s),
        "surface": hls(bg_h, 0.16, min(bg_s, 0.3)),
        "fg": hls(bg_h, 0.86, min(bg_s, 0.25)),
        "muted": hls(bg_h, 0.50, min(bg_s, 0.2)),
        "accent": hls(acc_h, 0.72, acc_s),
        "accent2": hls(acc2_h, 0.74, acc_s),
    }

    # Terminal colours: keep the usual meaning (red = errors, green = ok, ...)
    # but pull each hue toward a matching colour from the wallpaper.
    for name, base in ANSI_HUES.items():
        near = [c for c in info if c[3] > 0.2 and hue_distance(c[1], base) < 25]
        h = max(near, key=lambda c: c[0])[1] if near else base
        pal[name] = hls(h, 0.70, 0.55)
        pal["bright_" + name] = hls(h, 0.78, 0.62)

    pal["black"] = hls(bg_h, 0.20, min(bg_s, 0.3))
    pal["bright_black"] = hls(bg_h, 0.42, min(bg_s, 0.2))
    pal["white"] = hls(bg_h, 0.80, min(bg_s, 0.15))
    pal["bright_white"] = hls(bg_h, 0.93, min(bg_s, 0.1))
    pal["urgent"] = pal["red"]
    return pal


# ---------------------------------------------------------------- writers
def write(path, text):
    """Write a file atomically so apps never read a half-written config."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text)
    tmp.replace(path)


ANSI_ORDER = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]


def kitty_colors(p):
    lines = ["# Generated by ~/.config/rice/theme-sync.py (overwritten on wallpaper change)",
             f"background_opacity {TERMINAL_ALPHA}",
             f"background #{p['bg']}",
             f"foreground #{p['fg']}",
             f"selection_background #{p['surface']}",
             f"selection_foreground #{p['fg']}",
             f"cursor #{p['accent']}",
             f"cursor_text_color #{p['bg']}",
             f"url_color #{p['accent']}",
             f"active_border_color #{p['accent']}",
             f"inactive_border_color #{p['surface']}"]
    for i, name in enumerate(ANSI_ORDER):
        lines.append(f"color{i} #{p[name]}")
    for i, name in enumerate(ANSI_ORDER):
        lines.append(f"color{i + 8} #{p['bright_' + name]}")
    return "\n".join(lines) + "\n"


def waybar_colors(p):
    names = ["bg", "surface", "fg", "muted", "accent", "accent2", "urgent",
             "red", "green", "yellow", "blue", "magenta", "cyan"]
    lines = ["/* Generated by ~/.config/rice/theme-sync.py */"]
    lines += [f"@define-color {n} #{p[n]};" for n in names]
    return "\n".join(lines) + "\n"


def fuzzel_config(p):
    return f"""# Generated by ~/.config/rice/theme-sync.py (overwritten on wallpaper change)
# To change layout permanently, edit the template in theme-sync.py.
[main]
font={FONT}:size=15
terminal=kitty
prompt="❯  "
layer=overlay
width=36
lines=10
horizontal-pad=20
vertical-pad=14
inner-pad=10

[colors]
background={p['bg']}{PANEL_ALPHA}
text={p['fg']}ff
prompt={p['accent']}ff
placeholder={p['muted']}ff
input={p['fg']}ff
match={p['accent']}ff
selection={p['surface']}ff
selection-text={p['fg']}ff
selection-match={p['accent2']}ff
border={p['accent']}ff

[border]
width=2
radius=14
"""


def mako_config(p):
    return f"""# Generated by ~/.config/rice/theme-sync.py (overwritten on wallpaper change)
font={FONT} 14
background-color=#{p['bg']}{PANEL_ALPHA}
text-color=#{p['fg']}
border-color=#{p['accent']}
progress-color=over #{p['surface']}
border-size=2
border-radius=14
padding=14
margin=14
width=360
default-timeout=5000
anchor=top-right

[urgency=high]
border-color=#{p['urgent']}
default-timeout=0
"""


def cava_theme(p):
    # Bars fade from the second accent at the bottom to the main accent at the top.
    return f"""; Generated by ~/.config/rice/theme-sync.py (overwritten on wallpaper change)
[color]
gradient = 1
gradient_color_1 = '#{p['accent2']}'
gradient_color_2 = '#{p['accent']}'
gradient_color_3 = '#{p['fg']}'
"""


def rofi_colors(p):
    return f"""/* Generated by ~/.config/rice/theme-sync.py (overwritten on wallpaper change) */
* {{
    bg: #{p['bg']};
    bg-alpha: #{p['bg']}e6;
    surface: #{p['surface']};
    fg: #{p['fg']};
    muted: #{p['muted']};
    accent: #{p['accent']};
    accent-soft: #{p['accent']}33;
}}
"""


def regreet_css(p):
    # GTK 4 stylesheet for the ReGreet login screen. The wallpaper is drawn by
    # ReGreet itself; this styles the login card on top of it.
    return f"""/* Generated by ~/.config/rice/theme-sync.py (overwritten on wallpaper change) */
* {{
    font-family: "{FONT}";
}}

window {{
    color: #{p['fg']};
}}

frame, .card {{
    background-color: alpha(#{p['bg']}, 0.82);
    border: 2px solid #{p['accent']};
    border-radius: 18px;
    padding: 20px;
}}

label {{
    color: #{p['fg']};
}}

entry, combobox button, dropdown button {{
    background-color: #{p['surface']};
    color: #{p['fg']};
    border: 1px solid alpha(#{p['accent']}, 0.35);
    border-radius: 10px;
    padding: 6px 10px;
}}

entry:focus-within {{
    border-color: #{p['accent']};
}}

button {{
    background-color: #{p['surface']};
    color: #{p['fg']};
    border-radius: 10px;
    border: 1px solid alpha(#{p['accent']}, 0.35);
}}

button:hover {{
    background-color: alpha(#{p['accent']}, 0.25);
}}

button.suggested-action {{
    background-color: #{p['accent']};
    color: #{p['bg']};
}}

button.destructive-action {{
    background-color: #{p['urgent']};
    color: #{p['bg']};
}}
"""


def gtk_colors(p):
    # Named colours understood by libadwaita (GTK 4 apps) and by the adw-gtk3
    # theme (GTK 3 apps such as Thunar and Blueman), so both follow the wallpaper.
    pairs = {
        "accent_color": p["accent"], "accent_bg_color": p["accent"], "accent_fg_color": p["bg"],
        "destructive_bg_color": p["urgent"], "destructive_fg_color": p["bg"],
        "window_bg_color": p["bg"], "window_fg_color": p["fg"],
        "view_bg_color": p["bg"], "view_fg_color": p["fg"],
        "headerbar_bg_color": p["surface"], "headerbar_fg_color": p["fg"],
        "headerbar_backdrop_color": p["bg"],
        "sidebar_bg_color": p["surface"], "sidebar_fg_color": p["fg"],
        "card_bg_color": p["surface"], "card_fg_color": p["fg"],
        "dialog_bg_color": p["surface"], "dialog_fg_color": p["fg"],
        "popover_bg_color": p["surface"], "popover_fg_color": p["fg"],
    }
    lines = ["/* Generated by ~/.config/rice/theme-sync.py (overwritten on wallpaper change) */"]
    lines += [f"@define-color {k} #{v};" for k, v in pairs.items()]
    return "\n".join(lines) + "\n"


def hyprlock_config(p, wallpaper):
    bg = f"path = {wallpaper}" if wallpaper else "color = rgb(" + p["bg"] + ")"
    return f"""# Generated by ~/.config/rice/theme-sync.py (overwritten on wallpaper change)
# Lock screen: blurred wallpaper, clock, date and a password box in your colours.

general {{
    hide_cursor = true
}}

background {{
    monitor =
    {bg}
    blur_passes = 3
    blur_size = 7
    brightness = 0.7
}}

label {{
    monitor =
    text = $TIME
    color = rgb({p['fg']})
    font_size = 96
    font_family = {FONT}
    position = 0, 160
    halign = center
    valign = center
}}

label {{
    monitor =
    text = cmd[update:60000] date +"%A, %d %B"
    color = rgb({p['accent']})
    font_size = 20
    font_family = {FONT}
    position = 0, 60
    halign = center
    valign = center
}}

input-field {{
    monitor =
    size = 320, 56
    outline_thickness = 2
    outer_color = rgb({p['accent']})
    inner_color = rgba({p['bg']}cc)
    font_color = rgb({p['fg']})
    check_color = rgb({p['accent2']})
    fail_color = rgb({p['urgent']})
    placeholder_text = password
    fade_on_empty = false
    rounding = 14
    position = 0, -60
    halign = center
    valign = center
}}
"""


def imv_config(p):
    return f"""# Generated by ~/.config/rice/theme-sync.py (overwritten on wallpaper change)
[options]
background = {p['bg']}
overlay_font = {FONT}:12
overlay_text_color = {p['fg']}
overlay_background_color = {p['surface']}
"""


def reload_gtk():
    """Make open GTK apps re-read their colours by briefly switching theme and
    back (a common trick; 43PR/dotfiles uses the same idea)."""
    if not shutil.which("gsettings"):
        return
    key = "org.gnome.desktop.interface"
    try:
        cur = subprocess.run(["gsettings", "get", key, "gtk-theme"], capture_output=True,
                             text=True, timeout=5).stdout.strip().strip("'")
    except (OSError, subprocess.TimeoutExpired):
        return
    if not cur:
        return
    tmp = "Adwaita" if cur != "Adwaita" else "HighContrast"
    run_quiet(["gsettings", "set", key, "gtk-theme", tmp])
    run_quiet(["sleep", "0.3"])
    run_quiet(["gsettings", "set", key, "gtk-theme", cur])


def hypr_colors(p):
    return f"""-- Generated by ~/.config/rice/theme-sync.py (overwritten on wallpaper change)
return {{
    active   = "rgba({p['accent']}ee)",
    inactive = "rgba({p['surface']}88)",
}}
"""


# ---------------------------------------------------------------- reloads
def run_quiet(cmd):
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       stdin=subprocess.DEVNULL, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        pass


def recolor_open_terminals(p):
    """Send colour escape codes to terminals that are already open
    (the same trick pywal uses). Only touches terminals owned by you."""
    seq = "".join(f"\033]4;{i};#{p[n]}\033\\" for i, n in enumerate(ANSI_ORDER))
    seq += "".join(f"\033]4;{i + 8};#{p['bright_' + n]}\033\\" for i, n in enumerate(ANSI_ORDER))
    seq += f"\033]10;#{p['fg']}\033\\\033]11;#{p['bg']}\033\\\033]12;#{p['accent']}\033\\"
    uid = os.getuid()
    for tty in Path("/dev/pts").glob("[0-9]*"):
        try:
            st = tty.stat()
            if st.st_uid == uid and stat.S_ISCHR(st.st_mode) and os.access(tty, os.W_OK):
                with open(tty, "w") as f:
                    f.write(seq)
        except OSError:
            pass


def apply(p, wallpaper=None):
    write(CONFIG / "kitty" / "colors.conf", kitty_colors(p))
    write(CONFIG / "waybar" / "colors.css", waybar_colors(p))
    write(CONFIG / "fuzzel" / "fuzzel.ini", fuzzel_config(p))
    write(CONFIG / "mako" / "config", mako_config(p))
    write(CONFIG / "hypr" / "colors.lua", hypr_colors(p))
    write(CONFIG / "cava" / "themes" / "rice", cava_theme(p))
    write(CONFIG / "rice" / "colors.rasi", rofi_colors(p))
    write(CONFIG / "gtk-3.0" / "colors.css", gtk_colors(p))
    write(CONFIG / "gtk-4.0" / "colors.css", gtk_colors(p))
    write(CONFIG / "hypr" / "hyprlock.conf", hyprlock_config(p, wallpaper))
    write(CONFIG / "imv" / "config", imv_config(p))
    write(CACHE / "palette.json", json.dumps(p, indent=2) + "\n")

    # Login screen colours, only if login-setup.sh created the shared folder.
    if LOGIN_DIR.is_dir() and os.access(LOGIN_DIR, os.W_OK):
        css = LOGIN_DIR / "regreet.css"
        write(css, regreet_css(p))
        css.chmod(0o644)    # the login screen runs as another user and must read it

    run_quiet(["pkill", "-USR2", "-x", "waybar"])   # reload waybar style
    run_quiet(["pkill", "-USR2", "-x", "cava"])     # reload cava colours
    run_quiet(["pkill", "-USR1", "-x", "kitty"])    # kitty re-reads its config (colours + glass)
    run_quiet(["makoctl", "reload"])
    run_quiet(["hyprctl", "reload"])                # picks up new border colours
    recolor_open_terminals(p)
    reload_gtk()                                    # Thunar, settings apps, ...


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    arg = sys.argv[1]
    image = None
    if arg == "--default":
        palette = dict(DEFAULT_PALETTE)
    else:
        image = Path(arg).expanduser().resolve()
        if not image.is_file():
            sys.exit(f"theme-sync: not a file: {image}")
        palette = build_palette(image)
    apply(palette, image)
    print(f"theme-sync: accent #{palette['accent']}, background #{palette['bg']}")


if __name__ == "__main__":
    main()
