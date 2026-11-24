#!/usr/bin/env bash
# wallpaper.sh: change wallpaper with an animated transition, then recolour
# the desktop (and the login screen, if set up) to match it.
#
#   wallpaper.sh pick      centred carousel of ~/Pictures/Wallpapers (Super+Shift+W);
#                          Quickshell picker, or a rofi strip if quickshell is missing
#   wallpaper.sh random    pick a random one (right-click the bar's wallpaper icon)
#   wallpaper.sh restore   show the last wallpaper again (runs at login)
#   wallpaper.sh <file>    set a specific image or video
#
# Live wallpapers: GIFs play through awww. Videos (mp4, webm, mkv, mov) play
# through mpvpaper (AUR: yay -S mpvpaper), muted and looping, on a layer just
# above awww; a still frame sits underneath and is used for the colours.
# Game mode (Mod+G) pauses the video; it also pauses behind fullscreen windows.
#
# Idea credit: 43PR/dotfiles (MIT) uses awww transitions and a centred Quickshell picker.
# This is a separate, smaller implementation.

set -uo pipefail

WALL_DIR="${WALL_DIR:-$HOME/Pictures/Wallpapers}"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rice"
STATE_FILE="$STATE_DIR/wallpaper"
THUMB_DIR="$STATE_DIR/thumbs-960"            # sharp enough for the big centre card
FRAME_DIR="$STATE_DIR/frames"                # still frames of video wallpapers
GAMEMODE_STATE="$STATE_DIR/gamemode"
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
        -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.avif' \
        -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.m4v' \) \
        -printf '%f\n' 2>/dev/null | sort
}

is_video() { [[ "${1,,}" =~ \.(mp4|webm|mkv|mov|m4v)$ ]]; }

# Full-size still frame of a video (1 second in), made once and reused.
video_frame() {
    local video="$1" frame
    frame="$FRAME_DIR/$(basename "$video").png"
    mkdir -p "$FRAME_DIR"
    if [[ ! -f "$frame" || "$video" -nt "$frame" ]]; then
        ffmpeg -loglevel error -y -ss 1 -i "$video" -frames:v 1 "$frame" 2>/dev/null \
            || ffmpeg -loglevel error -y -i "$video" -frames:v 1 "$frame" 2>/dev/null
    fi
    printf '%s\n' "$frame"
}

stop_video() { pkill -x mpvpaper 2>/dev/null; return 0; }

# Play a video wallpaper: muted, looping, hardware-decoded, filling the screen.
# -p -a FULL pauses it automatically while a fullscreen window covers it.
start_video() {
    local video="$1"
    stop_video
    if ! command -v mpvpaper >/dev/null; then
        notify "Wallpaper" "Video wallpapers need mpvpaper: yay -S mpvpaper (showing a still frame for now)"
        return 1
    fi
    setsid -f mpvpaper -p -a FULL -l bottom \
        -o "no-audio loop hwdec=auto panscan=1.0" ALL "$video" >/dev/null 2>&1
    # Game mode on: start paused.
    if [[ -f "$GAMEMODE_STATE" ]]; then
        sleep 1; pkill -STOP -x mpvpaper 2>/dev/null
    fi
    return 0
}

# 16:9 previews, made once and reused until the wallpaper file changes.
make_thumbnails() {
    mkdir -p "$THUMB_DIR"
    local f thumb made=0
    for f in "$@"; do
        thumb="$THUMB_DIR/$f.png"
        if [[ ! -f "$thumb" || "$WALL_DIR/$f" -nt "$thumb" ]]; then
            (( made == 0 )) && notify "Wallpaper" "Making previews, one moment..."
            made=1
            local src="${WALL_DIR}/${f}"
            is_video "$src" && src="$(video_frame "$src")"
            magick_cmd "${src}[0]" -thumbnail '960x540^' -gravity center \
                -extent 960x540 "$thumb" 2>/dev/null
        fi
    done
}

# Copy the wallpaper for the login screen (only if login-setup.sh was run).
update_login_wallpaper() {
    local img="$1"
    [[ -d "$LOGIN_DIR" && -w "$LOGIN_DIR" ]] || return 0
    is_video "$img" && img="$(video_frame "$img")"     # login screen gets a still frame
    # Softly blurred and slightly darkened, so the glass login card stands out.
    magick_cmd "${img}[0]" -resize '1920x1080^' -blur 0x14 -modulate 85 -quality 90 \
        "$LOGIN_DIR/wallpaper.jpg.tmp" 2>/dev/null \
        && mv "$LOGIN_DIR/wallpaper.jpg.tmp" "$LOGIN_DIR/wallpaper.jpg" \
        && chmod 644 "$LOGIN_DIR/wallpaper.jpg"
}

set_wallpaper() {
    local wall="$1" transition="$2" img
    [[ -f "$wall" ]] || { notify "Wallpaper" "File not found: $wall"; return 1; }
    ensure_daemon || return 1

    # Videos: awww shows a still frame (also used for the colours), mpvpaper plays on top.
    img="$wall"
    is_video "$wall" && img="$(video_frame "$wall")"

    awww img "$img" --transition-type "$transition" \
        --transition-duration "$DURATION" --transition-fps "$FPS"

    if is_video "$wall"; then
        # Let the transition to the still frame finish, then start the video.
        [[ "$transition" != "none" ]] && sleep "$DURATION"
        start_video "$wall"
    else
        stop_video
    fi

    mkdir -p "$STATE_DIR"
    printf '%s\n' "$wall" > "$STATE_FILE"

    # Recolour everything and update the login screen, in the background so the
    # transition stays smooth. Skipped on restore (nothing changed since last time).
    if [[ "$transition" != "none" ]]; then
        setsid -f bash -c '
            python3 "$1/theme-sync.py" "$2"
            "$1/wallpaper.sh" --login-copy "$2"
        ' _ "$RICE_DIR" "$img" >>"$STATE_DIR/theme-sync.log" 2>&1
    fi
}

# Quick fade to show a picture without saving it or recolouring anything.
# Videos preview as their still frame; a playing video is stopped so the
# preview is visible (Esc / --restore brings it back).
preview_wallpaper() {
    ensure_daemon || return 1
    local img="$1"
    is_video "$img" && img="$(video_frame "$img")"
    stop_video
    awww img "$img" --transition-type fade --transition-duration 0.4 --transition-fps "$FPS"
}

random_transition() { echo "${TRANSITIONS[RANDOM % ${#TRANSITIONS[@]}]}"; }

# Centred one-row picker (rice/wallpicker.qml, needs the quickshell package).
# The list, colours and current wallpaper are passed in environment variables.
pick_quickshell() {
    local walls
    walls="$(python3 -c '
import json, os, sys
wall_dir, thumb_dir = sys.argv[1], sys.argv[2]
video = (".mp4", ".webm", ".mkv", ".mov", ".m4v")
print(json.dumps([{"name": f, "path": os.path.join(wall_dir, f),
                   "thumb": os.path.join(thumb_dir, f + ".png"),
                   "live": f.lower().endswith(video + (".gif",))} for f in sys.argv[3:]]))
' "$WALL_DIR" "$THUMB_DIR" "${files[@]}")"
    RICE_WALLS="$walls" \
    RICE_PALETTE="$(cat "$STATE_DIR/palette.json" 2>/dev/null || echo '{}')" \
    RICE_WALL_SCRIPT="$(realpath "$0")" \
    RICE_WALL_CURRENT="$original" \
        qs -p "$RICE_DIR/wallpicker.qml" >>"$STATE_DIR/wallpicker.log" 2>&1
}

# Fallback when quickshell is not installed: rofi carousel strip.
# Space previews (rofi exits with code 10 and reopens on the same picture),
# Enter applies and recolours, Esc puts the original back.
pick_rofi() {
    local previewed=0 row=0 idx code
    while true; do
        idx="$(for f in "${files[@]}"; do
                   printf '%s\0icon\x1f%s\n' "$f" "$THUMB_DIR/$f.png"
               done | rofi -dmenu -i -show-icons -p "wallpaper" -format i \
                      -selected-row "$row" -kb-custom-1 space \
                      -mesg "Space: preview    Enter: apply    Esc: cancel" \
                      -theme "$RICE_DIR/wallpaper-picker.rasi")"
        code=$?
        case "$code" in
            0)  [[ -n "$idx" ]] && set_wallpaper "$WALL_DIR/${files[idx]}" "$(random_transition)"
                return ;;
            10) [[ -n "$idx" ]] || continue
                row="$idx"
                previewed=1
                preview_wallpaper "$WALL_DIR/${files[idx]}" ;;
            *)  if (( previewed )) && [[ -n "$original" && -f "$original" ]]; then
                    set_wallpaper "$original" none     # back to the original (restarts a video)
                fi
                return ;;
        esac
    done
}

case "${1:-pick}" in
    pick)
        # Pressing the key again closes the picker.
        if pgrep -f "wallpicker.qml" >/dev/null; then pkill -f "wallpicker.qml"; exit 0; fi
        if pgrep -x rofi >/dev/null; then pkill -x rofi; exit 0; fi
        mapfile -t files < <(list_wallpapers)
        if (( ${#files[@]} == 0 )); then
            notify "Wallpaper" "No wallpapers in $WALL_DIR"
            exit 1
        fi
        make_thumbnails "${files[@]}"
        original="$(cat "$STATE_FILE" 2>/dev/null)"
        if command -v qs >/dev/null; then
            pick_quickshell
        else
            pick_rofi
        fi
        ;;
    --apply)
        # Internal: used by the Quickshell picker.
        set_wallpaper "$2" "$(random_transition)"
        ;;
    --preview)
        # Internal: used by the Quickshell picker.
        preview_wallpaper "$2"
        ;;
    --restore)
        # Internal: picker cancelled after previewing; put the original back.
        last="$(cat "$STATE_FILE" 2>/dev/null)"
        [[ -n "$last" && -f "$last" ]] && set_wallpaper "$last" none
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
