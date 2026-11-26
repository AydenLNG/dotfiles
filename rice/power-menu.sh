#!/usr/bin/env bash
# power-menu.sh: small power menu (Mod+Escape and the bar's power button).

if pgrep -x rofi >/dev/null; then pkill -x rofi; exit 0; fi

# Nerd Font icons, written as escape codes so the file stays plain text.
options=(
    $'  lock'
    $'\U000f0343  logout'
    $'  suspend'
    $'  reboot'
    $'\U000f0425  shutdown'
)
# "reboot to windows" only on machines that still have Windows (its boot files
# on the EFI partition), so it never shows on a Linux-only laptop.
for efi in /boot/efi /boot /efi; do
    if [[ -d "$efi/EFI/Microsoft/Boot" ]]; then
        options=("${options[@]:0:4}" $'\uf17a  reboot to windows' "${options[@]:4}")
        break
    fi
done

choice="$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "power" -theme "$HOME/.config/rice/menu.rasi" -theme-str "window { width: 280px; } listview { lines: ${#options[@]}; }")" || exit 0

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
    *windows)  "$HOME/.config/rice/reboot-windows.sh" --window ;;
    *reboot)   systemctl reboot ;;
    *shutdown) systemctl poweroff ;;
esac
