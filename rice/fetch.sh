#!/usr/bin/env bash
# fetch.sh: fastfetch with a random logo that fits the window.
# The installer points the "fastfetch" command at this script (alias in ~/.bashrc).
#   Wide window:   random mix of pictures from ~/Pictures/Fetch and text logos
#   Medium window: small text logo only (a picture would overlap the info)
#   Narrow window: info only, no logo
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

shopt -s nullglob nocaseglob
images=("$HOME"/Pictures/Fetch/*.{png,jpg,jpeg,webp})
shopt -u nullglob nocaseglob

if (( cols < MIN_COLS_LOGO )); then
    exec /usr/bin/fastfetch --logo none
fi

if (( cols >= MIN_COLS_IMAGE && ${#images[@]} > 0 )) && [[ "$TERM" == "xterm-kitty" ]] \
   && (( RANDOM % 100 < IMAGE_CHANCE )); then
    # kitty-icat places the picture in a fixed box of text cells (30 x 15), so it
    # stays the right size even after the font size changes (kitty/auto_font.py).
    exec /usr/bin/fastfetch --logo-type kitty-icat --logo-width 30 --logo-height 15 \
        --logo "${images[RANDOM % ${#images[@]}]}"
fi

if (( cols >= MIN_COLS_IMAGE )); then
    logo="${LOGOS[RANDOM % ${#LOGOS[@]}]}"
else
    logo="arch_small"          # the only one narrow enough here
fi
exec /usr/bin/fastfetch --logo-type builtin --logo "$logo"
