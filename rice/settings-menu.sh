#!/usr/bin/env bash
# settings-menu.sh: full settings list (Super+Shift+I, or Settings in the control centre).
# Everyday toggles live in the control centre (Super+I); this opens the full tools.

if pgrep -x rofi >/dev/null; then pkill -x rofi; exit 0; fi

RICE="$HOME/.config/rice"

# Run a terminal tool in its own floating kitty window (centred, on top) and keep
# it open until Enter is pressed. setsid detaches it from this menu script.
in_terminal() {
    setsid -f kitty --class rice-dialog --title "$2" \
        bash -c "printf '\\e[1m%s\\e[0m\\n\\n' \"\$1\"; $1; echo; read -rp 'Press Enter to close'" _ "$2" \
        >/dev/null 2>&1
}

missing() { notify-send "Settings" "$1 is not installed. Run the rice installer again."; }
open_app() { if command -v "$1" >/dev/null; then setsid -f "$@" >/dev/null 2>&1; else missing "$1"; fi; }

# Login screen: one-time setup, then a small options menu once it is installed.
login_ready() { grep -qs regreet /etc/greetd/config.toml; }
if login_ready; then login_item=$'\uf090  Login screen options'; else login_item=$'\uf090  Set up login screen'; fi

login_options() {
    local pick
    pick="$(printf '%s\n' "Refresh style (wallpaper and colours)" "Run setup again" "Turn off (back to text login)" \
        | rofi -dmenu -i -p "login screen" -theme "$HOME/.config/rice/menu.rasi" -theme-str 'window { width: 420px; } listview { lines: 3; }')" || return
    case "$pick" in
        Refresh*) python3 "$RICE/theme-sync.py" "$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/rice/wallpaper" 2>/dev/null)" >/dev/null 2>&1
                  "$RICE/wallpaper.sh" --login-copy
                  notify-send "Login screen" "Style refreshed. You will see it at the next login." ;;
        Run*)     in_terminal "$RICE/login-setup.sh" "Login screen setup" ;;
        Turn*)    in_terminal "$RICE/login-undo.sh" "Turn off login screen" ;;
    esac
}

# Nerd Font icons as escape codes so the file stays plain text.
items=(
    $'  Wallpaper'
    $'  Sound'
    $'  Wi-Fi and network'
    $'  Bluetooth'
    $'  Display'
    $'  Appearance (theme, icons, cursor)'
    $'  Weather location'
    "$login_item"
    $'  Keybinds'
    $'  Troubleshooting'
    $'  Update system'
)

choice="$(printf '%s\n' "${items[@]}" | rofi -dmenu -i -p "settings" -theme "$HOME/.config/rice/menu.rasi" -theme-str 'window { width: 420px; } listview { lines: 11; }')" || exit 0

case "$choice" in
    *Wallpaper)         "$RICE/wallpaper.sh" pick ;;
    *Sound)             open_app pavucontrol ;;
    *"Wi-Fi and network")
                        setsid -f kitty --class rice-dialog --title "Wi-Fi and network" nmtui >/dev/null 2>&1 ;;
    *Bluetooth)         open_app blueman-manager ;;
    *Display)
        notify-send "Display" "nwg-displays saves to monitors.conf, which a Lua Hyprland config does not read. To keep a setting, copy it into an hl.monitor() line in hyprland.lua."
        open_app nwg-displays ;;
    *Appearance*)       open_app nwg-look ;;
    *"Weather location")
        kitty nano "$RICE/weather.conf"
        pkill -x waybar; setsid -f waybar >/dev/null 2>&1 ;;
    *"Set up login screen")   in_terminal "$RICE/login-setup.sh" "Login screen setup" ;;
    *"Login screen options")  login_options ;;
    *Keybinds)          "$RICE/keybinds.sh" ;;
    *Troubleshooting)   "$RICE/help.sh" ;;
    *"Update system")   in_terminal "sudo pacman -Syu" "Update system" ;;
esac
