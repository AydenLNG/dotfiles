#!/usr/bin/env bash
# power-menu.sh: small power menu using fuzzel (bar power button).

if pgrep -x fuzzel >/dev/null; then pkill -x fuzzel; exit 0; fi

# Nerd Font icons, written as escape codes so the file stays plain text.
options=(
    $'  lock'
    $'\U000f0343  logout'
    $'  suspend'
    $'  reboot'
    $'\U000f0425  shutdown'
)
choice="$(printf '%s\n' "${options[@]}" | fuzzel --dmenu --prompt "power ❯  " --lines 5 --width 20)" || exit 0

case "$choice" in
    *lock)
        if command -v hyprlock >/dev/null; then
            hyprlock
        else
            notify-send "Power" "Install hyprlock for a lock screen: sudo pacman -S hyprlock"
        fi
        ;;
    *logout)   hyprctl dispatch 'hl.dsp.exit()' ;;
    *suspend)  systemctl suspend ;;
    *reboot)   systemctl reboot ;;
    *shutdown) systemctl poweroff ;;
esac
