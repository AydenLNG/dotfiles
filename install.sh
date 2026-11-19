#!/usr/bin/env bash
# install.sh: install this Hyprland rice.     Run with:  bash install.sh
#
# What it does, in order (nothing else):
#   1. Lists the packages from packages.txt that are missing and asks once before
#      installing them with pacman (official repos only, no AUR). If one name
#      fails, it retries the rest one by one and lists what could not install.
#   2. Backs up every config file it is about to replace to
#      ~/.config/rice-backup/<date-time>/
#   3. Copies the configs into ~/.config (plain copies, no symlinks).
#   4. Sets the GTK theme to adw-gtk3-dark (so apps can follow the wallpaper).
#   5. Edits ~/.config/hypr/hyprland.lua: comments out old waybar/mako/swaybg/
#      awww-daemon autostart lines (rice.lua starts them now), points the file
#      manager at thunar, and adds require("rice") at the end.
#   6. Creates ~/Pictures/Wallpapers.
#
# Options:  SKIP_PACKAGES=1 bash install.sh   skip step 1

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$CONFIG/rice-backup/$(date +%Y%m%d-%H%M%S)"

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root (it uses sudo only for pacman)."

# ---------------------------------------------------------------- 1. packages
if [[ "${SKIP_PACKAGES:-0}" != 1 ]]; then
    command -v pacman >/dev/null || die "pacman not found. This is for Arch Linux."
    mapfile -t wanted < <(sed -E 's/#.*//; s/[[:space:]]+//g; /^$/d' "$REPO/packages.txt")
    missing=()
    for p in "${wanted[@]}"; do
        pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if (( ${#missing[@]} )); then
        say "Missing packages (${#missing[@]}): ${missing[*]}"
        read -rp "Install them with pacman now? [y/N] " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            if ! sudo pacman -S --needed "${missing[@]}"; then
                # One bad name makes pacman refuse the whole list, so retry
                # one by one and report what could not be installed.
                warn "Batch install failed. Trying packages one at a time..."
                failed=()
                for p in "${missing[@]}"; do
                    sudo pacman -S --needed --noconfirm "$p" >/dev/null 2>&1 || failed+=("$p")
                done
                (( ${#failed[@]} )) && warn "Could not install: ${failed[*]}"
            fi
        else
            warn "Skipped. Some features will not work until these are installed."
        fi
    else
        say "All packages already installed."
    fi
fi

# ---------------------------------------------------------------- 2+3. backup and copy
# Files from this repo, copied to the same path inside ~/.config
FILES=(
    hypr/rice.lua hypr/colors.lua hypr/hyprlock.conf
    waybar/config.jsonc waybar/style.css waybar/colors.css
    foot/foot.ini foot/colors.ini
    fuzzel/fuzzel.ini
    mako/config
    cava/config
    imv/config
    gtk-3.0/gtk.css gtk-3.0/settings.ini gtk-3.0/colors.css
    gtk-4.0/gtk.css gtk-4.0/settings.ini gtk-4.0/colors.css
    rice/theme-sync.py rice/wallpaper.sh rice/power-menu.sh rice/weather.sh
    rice/settings-menu.sh rice/keybinds.sh rice/screenshot.sh
    rice/login-setup.sh rice/login-undo.sh
    rice/wallpaper-picker.rasi rice/colors.rasi
)

backed_up=0
backup() {
    local dest="$CONFIG/$1"
    if [[ -e "$dest" ]]; then
        mkdir -p "$(dirname "$BACKUP/$1")"
        cp -a "$dest" "$BACKUP/$1"
        backed_up=1
    fi
}

say "Copying configs into $CONFIG"
for f in "${FILES[@]}"; do
    backup "$f"
    mode=644
    [[ "$f" == rice/*.sh || "$f" == rice/*.py ]] && mode=755
    install -D -m "$mode" "$REPO/$f" "$CONFIG/$f"
done

# Your weather location: only copied the first time, so reinstalling never
# overwrites the place you set.
if [[ ! -f "$CONFIG/rice/weather.conf" ]]; then
    install -D -m 644 "$REPO/rice/weather.conf" "$CONFIG/rice/weather.conf"
fi

# An older waybar "config" file (without .jsonc) would be loaded instead of ours.
if [[ -f "$CONFIG/waybar/config" ]]; then
    backup waybar/config
    rm "$CONFIG/waybar/config"
    warn "Moved old ~/.config/waybar/config to the backup (it would override config.jsonc)."
fi

# ---------------------------------------------------------------- 4. GTK theme
# On Wayland, GTK apps read these settings (settings.ini alone is not enough).
if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
fi

# The copies above reset colour files to the default palette. Rebuild them from
# your current wallpaper (or the default palette on a first install).
if command -v python3 >/dev/null; then
    last_wall="$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/rice/wallpaper" 2>/dev/null || true)"
    if [[ -n "$last_wall" && -f "$last_wall" ]]; then
        python3 "$CONFIG/rice/theme-sync.py" "$last_wall" >/dev/null 2>&1 || true
    else
        python3 "$CONFIG/rice/theme-sync.py" --default >/dev/null 2>&1 || true
    fi
fi

# ---------------------------------------------------------------- 5. hyprland.lua
HL="$CONFIG/hypr/hyprland.lua"
if [[ -f "$HL" ]]; then
    backup hypr/hyprland.lua
    # Comment out autostart lines that rice.lua now handles.
    sed -E -i 's/^([[:space:]]*)(hl\.exec_cmd\("(waybar|mako|awww-daemon|swaybg)[^"]*"\).*)$/\1-- [rice] \2/' "$HL"
    # Default config's file manager (Mod+E) -> thunar.
    sed -E -i 's/^([[:space:]]*(local[[:space:]]+)?fileManager[[:space:]]*=[[:space:]]*)"[^"]*"/\1"thunar"/' "$HL"
    if ! grep -q 'require("rice")' "$HL"; then
        printf '\n-- Rice: glass look, wallpaper picker, synced colours\nrequire("rice")\n' >> "$HL"
    fi
    say "Updated hyprland.lua (old autostart lines are commented with '-- [rice]')."
else
    warn "No ~/.config/hypr/hyprland.lua yet. Start Hyprland once so it creates one,"
    warn "then run this installer again (or add require(\"rice\") to the end yourself)."
fi

# ---------------------------------------------------------------- 6. wallpapers
mkdir -p "$HOME/Pictures/Wallpapers"

# ---------------------------------------------------------------- done
echo
say "Done."
if (( backed_up )); then say "Your previous files are saved in: $BACKUP"; fi
cat <<'EOF'

Next steps:
  1. Put some images in ~/Pictures/Wallpapers
  2. Log out of Hyprland and back in
  3. Press Super+Shift+W to pick a wallpaper. Everything recolours to match.
  4. Super+I opens the settings menu (sound, Wi-Fi, appearance, keybinds...)
  5. For weather in the bar, set LOCATION in ~/.config/rice/weather.conf
     (it is never detected automatically).
  6. Optional graphical login screen: ~/.config/rice/login-setup.sh
     (read what it does first; undo with ~/.config/rice/login-undo.sh)

On a keyboard without a Windows key, edit ~/.config/hypr/rice.lua and set:
  local mod = "ALT"
EOF
