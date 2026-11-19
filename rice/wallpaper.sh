#!/usr/bin/env bash
# wallpaper.sh: change wallpaper with an animated transition, then recolour
# the desktop (and the login screen, if set up) to match it.
#
#   wallpaper.sh pick      preview grid of ~/Pictures/Wallpapers (Super+Shift+W)
#   wallpaper.sh random    pick a random one (right-click the bar's wallpaper icon)
#   wallpaper.sh restore   show the last wallpaper again (runs at login)
#   wallpaper.sh <file>    set a specific image
#
# Idea credit: 43PR/dotfiles (MIT) uses awww transitions for its picker.
# This is a separate, smaller implementation using rofi instead of Quickshell.

set -uo pipefail

WALL_DIR="${WALL_DIR:-$HOME/Pictures/Wallpapers}"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rice"
STATE_FILE="$STATE_DIR/wallpaper"
THUMB_DIR="$STATE_DIR/thumbs"
RICE_DIR="$HOME/.config/rice"
LOGIN_DIR="/usr/local/share/rice-login"      # created by login-setup.sh

# Transition styles to rotate through. Full list: awww img --help
TRANSITIONS=(grow outer wipe wave center)
DURATION=1.2
FPS=60

notify() { command -v notify-send >/dev/null && notify-send -a wallpaper "$@"; }

magick_cmd() {
    if command -v magick >/dev/null; then magick "$@"; else convert "$@"; fi
}

ensure_daemon() {
    if ! awww query >/dev/null 2>&1; then
        setsid -f awww-daemon >/dev/null 2>&1
    fi
    for _ in $(seq 1 40); do                     # wait up to ~5 seconds
        awww query >/dev/null 2>&1 && return 0
        sleep 0.125
    done
    notify "Wallpaper" "awww-daemon did not start"
    return 1
}

list_wallpapers() {
    find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' \
        -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.avif' \) \
        -printf '%f\n' 2>/dev/null | sort
}

# Small 16:9 previews, made once and reused until the wallpaper file changes.
make_thumbnails() {
    mkdir -p "$THUMB_DIR"
    local f thumb made=0
    for f in "$@"; do
        thumb="$THUMB_DIR/$f.png"
        if [[ ! -f "$thumb" || "$WALL_DIR/$f" -nt "$thumb" ]]; then
            (( made == 0 )) && notify "Wallpaper" "Making previews, one moment..."
            made=1
            magick_cmd "${WALL_DIR}/${f}[0]" -thumbnail '400x225^' -gravity center \
                -extent 400x225 "$thumb" 2>/dev/null
        fi
    done
}

# Copy the wallpaper for the login screen (only if login-setup.sh was run).
update_login_wallpaper() {
    local img="$1"
    [[ -d "$LOGIN_DIR" && -w "$LOGIN_DIR" ]] || return 0
    magick_cmd "${img}[0]" -resize '2560x1440^' -quality 90 "$LOGIN_DIR/wallpaper.jpg.tmp" 2>/dev/null \
        && mv "$LOGIN_DIR/wallpaper.jpg.tmp" "$LOGIN_DIR/wallpaper.jpg" \
        && chmod 644 "$LOGIN_DIR/wallpaper.jpg"
}

set_wallpaper() {
    local img="$1" transition="$2"
    [[ -f "$img" ]] || { notify "Wallpaper" "File not found: $img"; return 1; }
    ensure_daemon || return 1

    awww img "$img" --transition-type "$transition" \
        --transition-duration "$DURATION" --transition-fps "$FPS"

    mkdir -p "$STATE_DIR"
    printf '%s\n' "$img" > "$STATE_FILE"

    # Recolour everything and update the login screen, in the background so the
    # transition stays smooth. Skipped on restore (nothing changed since last time).
    if [[ "$transition" != "none" ]]; then
        setsid -f bash -c '
            python3 "$1/theme-sync.py" "$2"
            "$1/wallpaper.sh" --login-copy "$2"
        ' _ "$RICE_DIR" "$img" >>"$STATE_DIR/theme-sync.log" 2>&1
    fi
}

random_transition() { echo "${TRANSITIONS[RANDOM % ${#TRANSITIONS[@]}]}"; }

case "${1:-pick}" in
    pick)
        # Pressing the key again closes the picker.
        if pgrep -x rofi >/dev/null; then pkill -x rofi; exit 0; fi
        mapfile -t files < <(list_wallpapers)
        if (( ${#files[@]} == 0 )); then
            notify "Wallpaper" "No images in $WALL_DIR"
            exit 1
        fi
        make_thumbnails "${files[@]}"
        # rofi's icon protocol: "name\0icon\x1f/path/to/icon"
        choice="$(for f in "${files[@]}"; do
                      printf '%s\0icon\x1f%s\n' "$f" "$THUMB_DIR/$f.png"
                  done | rofi -dmenu -i -show-icons -p "wallpaper" \
                         -theme "$RICE_DIR/wallpaper-picker.rasi")" || exit 0
        [[ -n "$choice" ]] && set_wallpaper "$WALL_DIR/$choice" "$(random_transition)"
        ;;
    random)
        mapfile -t files < <(list_wallpapers)
        (( ${#files[@]} > 0 )) || { notify "Wallpaper" "No images in $WALL_DIR"; exit 1; }
        current="$(basename "$(cat "$STATE_FILE" 2>/dev/null)" 2>/dev/null)"
        pick="${files[RANDOM % ${#files[@]}]}"
        # Avoid picking the same one twice in a row when there is a choice.
        if (( ${#files[@]} > 1 )); then
            while [[ "$pick" == "$current" ]]; do pick="${files[RANDOM % ${#files[@]}]}"; done
        fi
        set_wallpaper "$WALL_DIR/$pick" "$(random_transition)"
        ;;
    restore)
        last="$(cat "$STATE_FILE" 2>/dev/null)"
        if [[ -n "$last" && -f "$last" ]]; then
            set_wallpaper "$last" none    # colours were already saved last time
        else
            ensure_daemon                 # first login: just start the daemon
        fi
        ;;
    --login-copy)
        # Internal: used after a wallpaper change, and by login-setup.sh.
        update_login_wallpaper "${2:-$(cat "$STATE_FILE" 2>/dev/null)}"
        ;;
    -h|--help)
        sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    *)
        set_wallpaper "$(realpath "$1")" "$(random_transition)"
        ;;
esac
