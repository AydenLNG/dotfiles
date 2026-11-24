#!/usr/bin/env bash
# reboot-windows.sh: restart straight into Windows, once (Mod+Ctrl+Alt+Delete,
# or "Reboot to Windows" in the power menu). The restart after that goes back
# to Arch as normal, because grub-reboot only sets the NEXT boot.
# Asks for your password every time (no permanent root rule is added).

# Keybind and power menu pass --window: open this in a small terminal window.
# (Checking for a terminal is not enough: Hyprland started from a login screen
# or TTY hands its programs a terminal they cannot show, so it would wait unseen.)
if [[ "${1:-}" == "--window" ]]; then
    exec setsid -f kitty --class rice-dialog --title "Reboot to Windows" bash "$(realpath "$0")"
fi

GRUB_CFG=/boot/grub/grub.cfg
GRUB_DEFAULTS=/etc/default/grub

pause_exit() { echo; read -rp "Press Enter to close." _; exit "${1:-0}"; }

echo "Reboot to Windows"
echo "-----------------"
echo "Restarts once into Windows; the next restart comes back to Arch."
echo "Close this window now if you pressed the keys by mistake."
echo
sudo -v || pause_exit 1

# One-time setup: GRUB must allow one-off choices (GRUB_DEFAULT=saved).
if ! grep -q '^GRUB_DEFAULT=saved' "$GRUB_DEFAULTS"; then
    echo "One-time setup needed: GRUB has to allow one-off boot choices."
    echo "This changes GRUB_DEFAULT to 'saved' in $GRUB_DEFAULTS"
    echo "(a backup is kept as $GRUB_DEFAULTS.rice-backup) and rebuilds the GRUB menu."
    echo "Arch stays the normal default."
    read -rp "Do it now? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || pause_exit 0
    sudo cp -n "$GRUB_DEFAULTS" "$GRUB_DEFAULTS.rice-backup"
    sudo sed -i -E 's/^#?GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' "$GRUB_DEFAULTS"
    sudo grub-mkconfig -o "$GRUB_CFG" || pause_exit 1
    echo
fi

# Find the Windows entry in the GRUB menu.
title="$(sudo grep -m1 -oP "menuentry '\KWindows Boot Manager \(on [^']+\)" "$GRUB_CFG")"
[[ -z "$title" ]] && title="$(sudo grep -oP "menuentry '\K[^']*Windows[^']*" "$GRUB_CFG" | grep -vi bootnext | head -1)"
if [[ -z "$title" ]]; then
    echo "Could not find Windows in the GRUB menu."
    echo "Fix: Super+Shift+N > 'Windows missing from the GRUB menu', then try again."
    pause_exit 1
fi

echo "Restarting into: $title"
for i in 5 4 3 2 1; do
    printf '\rIn %s... (Ctrl+C or close the window to cancel) ' "$i"
    sleep 1
done
echo
sudo grub-reboot "$title" && systemctl reboot
