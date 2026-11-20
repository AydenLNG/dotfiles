#!/usr/bin/env bash
# keybinds.sh: cheat sheet of this rice's keybinds (read-only list).
# "Mod" is the key set in ~/.config/hypr/rice.lua (Super by default, or Alt).

if pgrep -x fuzzel >/dev/null; then pkill -x fuzzel; exit 0; fi

cat <<'EOF' | fuzzel --dmenu --prompt "keybinds ❯  " --lines 18 --width 52 >/dev/null
Mod + I                 settings menu
Mod + Shift + W         wallpaper picker (previews)
Mod + Shift + V         clipboard history
Mod + Escape            power menu
Print                   screenshot of an area
Shift + Print           screenshot of the whole screen
Mod + Shift + A         screenshot of an area (no Print key)
Mod + Shift + F         screenshot of the whole screen (no Print key)
Bar: wallpaper icon     left click picker, right click random
Bar: media              click play/pause, scroll next/previous
Bar: volume             click mute, scroll volume
--- from your own hyprland.lua ---
Mod + Q                 terminal (default config)
Mod + C                 close window (default config)
Mod + M                 exit Hyprland (default config)
Mod + E                 file manager, Thunar (default config)
Mod + V                 toggle floating window (default config)
EOF
