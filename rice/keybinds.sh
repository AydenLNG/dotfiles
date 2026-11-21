#!/usr/bin/env bash
# keybinds.sh: cheat sheet of this rice's keybinds (read-only list).
# "Mod" is the key set in ~/.config/hypr/rice.lua (Super by default, or Alt).

if pgrep -x rofi >/dev/null; then pkill -x rofi; exit 0; fi

cat <<'EOF' | rofi -dmenu -i -p "keybinds" -theme "$HOME/.config/rice/menu.rasi" -theme-str 'window { width: 620px; } listview { lines: 20; }' >/dev/null
Mod + R                 app launcher (Apps / Windows / Run tabs)
Mod + I                 settings menu
Mod + N                 notification centre
Mod + G                 game mode on / off
Alt + Tab               next workspace (1-5, wraps)
Alt + Shift + Tab       previous workspace
Mod + Ctrl + Alt + Del  restart into Windows once (asks password)
Mod + /                 this keybind list
Mod + Shift + N         troubleshooting notes
Mod + Shift + W         wallpaper picker (A/D move, Space preview, Enter apply)
Mod + Shift + V         clipboard history
Mod + Escape            power menu
Print                   screenshot of an area
Shift + Print           screenshot of the whole screen
Mod + Shift + A         screenshot of an area (no Print key)
Mod + Shift + F         screenshot of the whole screen (no Print key)
Bar: wallpaper icon     left click picker, right click random
Bar: media              hover for buttons; click title play/pause; scroll next/prev
Bar: volume             hover for slider; click mute; right click sound settings
Bar: network / ping     hover for name / router ping; click network settings
Bar: chart icon         hover for CPU, GPU, RAM, weather, tray
Bar: clock              hover calendar; scroll months; right click year
Bar: bell               click notification centre, right click Do Not Disturb
--- from your own hyprland.lua ---
Mod + Q                 terminal (default config)
Mod + C                 close window (default config)
Mod + M                 exit Hyprland (default config)
Mod + E                 file manager, Thunar (default config)
Mod + V                 toggle floating window (default config)
EOF
