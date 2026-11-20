#!/usr/bin/env bash
# launcher.sh: app launcher (Mod+R). Pressing the key again closes it.
if pgrep -x rofi >/dev/null; then pkill -x rofi; exit 0; fi
exec rofi -show drun -theme "$HOME/.config/rice/launcher.rasi"
