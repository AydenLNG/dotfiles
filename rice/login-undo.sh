#!/usr/bin/env bash
# login-undo.sh: switch the graphical login screen off and go back to the
# plain text login. Your rice, files and wallpapers are not touched.
#
# Exactly what it does (uses sudo):
#   1. Disables greetd, so it no longer starts at boot.
#   2. Puts back the original /etc/greetd/config.toml and regreet.toml from the
#      .rice-backup copies, if they exist.
# The installed packages (greetd, greetd-regreet, cage) and
# /usr/local/share/rice-login are left in place, so login-setup.sh can turn
# it back on later. To remove them completely afterwards:
#     sudo pacman -Rns greetd-regreet cage greetd
#     sudo rm -r /usr/local/share/rice-login

set -euo pipefail
GREETD="/etc/greetd"

say() { printf '\033[1;34m::\033[0m %s\n' "$*"; }

[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not root."; exit 1; }

say "Disabling greetd"
sudo systemctl disable greetd.service || true

for f in config.toml regreet.toml; do
    if [[ -f "$GREETD/$f.rice-backup" ]]; then
        sudo mv "$GREETD/$f.rice-backup" "$GREETD/$f"
        say "Restored $GREETD/$f"
    fi
done

say "Done. Reboot to get the text login back: sudo reboot"
