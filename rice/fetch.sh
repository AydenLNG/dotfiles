#!/usr/bin/env bash
# fetch.sh: fastfetch sized to the window, so nothing runs off the screen.
# The installer points the "fastfetch" command at this script (alias in ~/.bashrc).
# Width decides the logo, height decides how many lines of info:
#   Logo:  wide + tall  -> random mix of ~/Pictures/Fetch pictures and text logos
#          smaller      -> small text logo; very small -> no logo
#   Info:  tall -> everything; medium -> the essentials; short -> six lines
# Nothing is changed in kitty (no font changes, no remote control).
# Settings: ~/.config/rice/fetch.conf. Any options you add are passed on,
# e.g. "fastfetch --logo arch2" still picks that logo.

IMAGE_CHANCE=50
LOGOS=(arch arch2 arch_small)
MIN_COLS_IMAGE=100
MIN_COLS_LOGO=72
CONF="$HOME/.config/rice/fetch.conf"
# shellcheck source=/dev/null
[[ -f "$CONF" ]] && source "$CONF"

# You asked for something specific: do exactly that.
(( $# > 0 )) && exec /usr/bin/fastfetch "$@"

cols="$(tput cols 2>/dev/null || echo 120)"
rows="$(tput lines 2>/dev/null || echo 40)"

# How much info fits (lines include the colour blocks and the prompt after).
MEDIUM="Title:Separator:OS:Kernel:Uptime:Packages:WM:Terminal:CPU:GPU:Memory:Disk:Break:Colors"
SMALL="OS:Kernel:CPU:GPU:Memory:Disk"
if   (( rows >= 34 )); then info=()                       # everything (config.jsonc)
elif (( rows >= 19 )); then info=(--structure "$MEDIUM")
else                        info=(--structure "$SMALL")
fi

shopt -s nullglob nocaseglob
images=("$HOME"/Pictures/Fetch/*.{png,jpg,jpeg,webp})
shopt -u nullglob nocaseglob

if (( cols < MIN_COLS_LOGO || rows < 10 )); then
    exec /usr/bin/fastfetch --logo none "${info[@]}"
fi

if (( cols >= MIN_COLS_IMAGE && rows >= 18 && ${#images[@]} > 0 )) && [[ "$TERM" == "xterm-kitty" ]] \
   && (( RANDOM % 100 < IMAGE_CHANCE )); then
    # kitty-icat places the picture in a fixed box of text cells (30 x 15), so it
    # stays the right size even after the font size changes (kitty/auto_font.py).
    exec /usr/bin/fastfetch --logo-type kitty-icat --logo-width 30 --logo-height 15 \
        --logo "${images[RANDOM % ${#images[@]}]}" "${info[@]}"
fi

# Full-size text logos are about 20 lines tall; arch_small is about 8.
if (( cols >= MIN_COLS_IMAGE && rows >= 23 )); then
    logo="${LOGOS[RANDOM % ${#LOGOS[@]}]}"
else
    logo="arch_small"          # small enough for this window
fi
exec /usr/bin/fastfetch --logo-type builtin --logo "$logo" "${info[@]}"
