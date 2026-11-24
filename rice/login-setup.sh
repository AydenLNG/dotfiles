#!/usr/bin/env bash
# login-setup.sh: graphical login screen (greetd + ReGreet) that uses your
# current wallpaper and colours, and follows them when you change wallpaper.
#
# This changes SYSTEM settings, so it uses sudo. Exactly what it does:
#   1. Installs greetd, greetd-regreet and cage from the official repos.
#   2. Creates /usr/local/share/rice-login (owned by you, readable by all) to
#      hold the login wallpaper and colours, so updating them never needs sudo.
#   3. Backs up /etc/greetd/config.toml to /etc/greetd/config.toml.rice-backup,
#      then writes a new one that starts ReGreet.
#   4. Writes /etc/greetd/regreet.toml (background, font, big clock, greeting,
#      power buttons).
#   5. Creates ReGreet's state and log folders (/var/lib/regreet, /var/log/regreet).
#   6. Enables greetd so it starts at the next boot. It does NOT stop your
#      current session.
#
# To go back to the text login: ~/.config/rice/login-undo.sh
# If the login screen ever fails: press Ctrl+Alt+F2, log in, run login-undo.sh.

set -euo pipefail

LOGIN_DIR="/usr/local/share/rice-login"
RICE_DIR="$HOME/.config/rice"
GREETD="/etc/greetd"

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Run as your normal user, not root (it uses sudo where needed)."
command -v pacman >/dev/null || die "pacman not found. This is for Arch Linux."

sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
echo
read -rp "Continue? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "Cancelled, nothing changed."; exit 0; }

# Another display manager would fight greetd for the screen.
other_dm="$(systemctl is-enabled display-manager.service 2>/dev/null || true)"
if [[ "$other_dm" == "enabled" ]] && ! systemctl is-enabled greetd.service >/dev/null 2>&1; then
    die "Another login manager is already enabled. Disable it first, then run this again."
fi

# 1. packages
say "Installing greetd, greetd-regreet and cage"
sudo pacman -S --needed greetd greetd-regreet cage

# 2. shared folder for wallpaper + colours
say "Creating $LOGIN_DIR"
sudo install -d -m 755 -o "$USER" -g "$(id -gn)" "$LOGIN_DIR"

# Fill it with the current wallpaper and colours.
last_wall="$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/rice/wallpaper" 2>/dev/null || true)"
if [[ -n "$last_wall" && -f "$last_wall" ]]; then
    python3 "$RICE_DIR/theme-sync.py" "$last_wall" >/dev/null
    "$RICE_DIR/wallpaper.sh" --login-copy "$last_wall"
else
    warn "No wallpaper chosen yet. Pick one with Super+Shift+W; the login screen will follow."
    python3 "$RICE_DIR/theme-sync.py" --default >/dev/null
fi

# 3. greetd config (backed up once, never overwritten after that)
if [[ -f "$GREETD/config.toml" && ! -f "$GREETD/config.toml.rice-backup" ]]; then
    sudo cp -a "$GREETD/config.toml" "$GREETD/config.toml.rice-backup"
    say "Backed up $GREETD/config.toml to config.toml.rice-backup"
fi
say "Writing $GREETD/config.toml"
sudo tee "$GREETD/config.toml" >/dev/null <<EOF
# Written by ~/.config/rice/login-setup.sh. Original: config.toml.rice-backup
[terminal]
vt = 1

[default_session]
# cage is a tiny compositor that shows a single app (ReGreet) full screen.
command = "env GTK_USE_PORTAL=0 GDK_DEBUG=no-portals cage -s -mlast -- regreet --style $LOGIN_DIR/regreet.css"
user = "greeter"
EOF

# 4. ReGreet config
if [[ -f "$GREETD/regreet.toml" && ! -f "$GREETD/regreet.toml.rice-backup" ]]; then
    sudo cp -a "$GREETD/regreet.toml" "$GREETD/regreet.toml.rice-backup"
fi
say "Writing $GREETD/regreet.toml"
sudo tee "$GREETD/regreet.toml" >/dev/null <<EOF
# Written by ~/.config/rice/login-setup.sh
[background]
path = "$LOGIN_DIR/wallpaper.jpg"
fit = "Cover"

[GTK]
application_prefer_dark_theme = true
font_name = "JetBrainsMono Nerd Font 14"
cursor_theme_name = "Adwaita"
icon_theme_name = "Adwaita"
theme_name = "Adwaita"

[commands]
reboot = [ "systemctl", "reboot" ]
poweroff = [ "systemctl", "poweroff" ]

[appearance]
greeting_msg = "Welcome back"

[widget.clock]
format = "%H:%M"
resolution = "1s"
label_width = 300
EOF

# 5. state + log folders for the greeter user
say "Creating /var/lib/regreet and /var/log/regreet"
sudo install -d -m 755 -o greeter -g greeter /var/lib/regreet /var/log/regreet

# 6. enable at boot
say "Enabling greetd for the next boot"
sudo systemctl enable greetd.service

echo
say "Done. Reboot to see the login screen: sudo reboot"
cat <<EOF

At the login screen: pick your user, choose the Hyprland session, enter your password.
If anything goes wrong there: press Ctrl+Alt+F2, log in, and run
    ~/.config/rice/login-undo.sh
then reboot to get the text login back.
EOF
