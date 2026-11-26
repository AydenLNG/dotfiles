#!/usr/bin/env bash
# keybinds.sh: cheat sheet of this rice's keybinds (read-only list).
# "Mod" is the key set in ~/.config/hypr/rice.lua (Super by default, or Alt).

if pgrep -x rofi >/dev/null; then pkill -x rofi; exit 0; fi

cat <<'EOF' | rofi -dmenu -i -p "keybinds" -theme "$HOME/.config/rice/menu.rasi" -theme-str 'window { width: 620px; } listview { lines: 22; }' >/dev/null
Mod + R                 app launcher (Apps / Windows / Run tabs)
Mod + I                 control centre (Esc or click outside closes)
Mod + Shift + I         full settings list
Mod + N                 notification centre
Mod + G                 game mode on / off (also pauses live wallpaper)
Mod + F                 fullscreen the focused window on / off
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
Bar: clock / status      click for the control centre
Bar: volume             scroll to change, right click mute
Bar: Wi-Fi              hover for name, right click pick a network
Bar: Bluetooth          hover for device, right click Bluetooth manager
Bar: battery (laptop)   hover for time left, click control centre
Bar: wallpaper icon     left click picker, right click random
Bar: bell               click notification centre, right click Do Not Disturb
Volume / brightness keys show an on-screen level
--- from your own hyprland.lua ---
Mod + Q                 terminal (default config)
Mod + C                 close window (default config)
Mod + M                 exit Hyprland (default config)
Mod + E                 file manager, Thunar (default config)
Mod + V                 toggle floating window (default config)
EOF
