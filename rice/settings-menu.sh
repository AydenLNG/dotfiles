#!/usr/bin/env bash
# settings-menu.sh: one menu (Super+I) that opens each settings tool.

if pgrep -x rofi >/dev/null; then pkill -x rofi; exit 0; fi

RICE="$HOME/.config/rice"

# Run a terminal tool in kitty and keep the window open until Enter is pressed.
in_terminal() { kitty bash -c "$1; echo; read -rp 'Press Enter to close'"; }

missing() { notify-send "Settings" "$1 is not installed. Run the rice installer again."; }
open_app() { if command -v "$1" >/dev/null; then setsid -f "$@" >/dev/null 2>&1; else missing "$1"; fi; }

# Nerd Font icons as escape codes so the file stays plain text.
items=(
    $'  Wallpaper'
    $'  Sound'
    $'  Wi-Fi and network'
    $'  Bluetooth'
    $'  Display'
    $'  Appearance (theme, icons, cursor)'
    $'  Weather location'
    $'  Lock screen'
    $'\uf090  Login screen'
    $'  Keybinds'
    $'  Troubleshooting'
    $'  Update system'
    $'  Power'
)

choice="$(printf '%s\n' "${items[@]}" | rofi -dmenu -i -p "settings" -theme "$HOME/.config/rice/menu.rasi" -theme-str 'window { width: 420px; } listview { lines: 13; }')" || exit 0

case "$choice" in
    *Wallpaper)         "$RICE/wallpaper.sh" pick ;;
    *Sound)             open_app pavucontrol ;;
    *"Wi-Fi and network")
                        open_app nm-connection-editor ;;
    *Bluetooth)         open_app blueman-manager ;;
    *Display)
        notify-send "Display" "nwg-displays saves to monitors.conf, which a Lua Hyprland config does not read. To keep a setting, copy it into an hl.monitor() line in hyprland.lua."
        open_app nwg-displays ;;
    *Appearance*)       open_app nwg-look ;;
    *"Weather location")
        kitty nano "$RICE/weather.conf"
        pkill -x waybar; setsid -f waybar >/dev/null 2>&1 ;;
    *"Lock screen")     open_app hyprlock ;;
    *"Login screen")    in_terminal "$RICE/login-setup.sh" ;;
    *Keybinds)          "$RICE/keybinds.sh" ;;
    *Troubleshooting)   "$RICE/help.sh" ;;
    *"Update system")   in_terminal "sudo pacman -Syu" ;;
    *Power)             "$RICE/power-menu.sh" ;;
esac
