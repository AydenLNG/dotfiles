#!/usr/bin/env bash
# idle.sh: auto lock / auto sleep (hypridle), set from the control centre.
#
#   idle.sh start           at login: write the config and start hypridle
#   idle.sh toggle          auto lock on / off
#   idle.sh set lock N      lock after N minutes idle
#   idle.sh set sleep N     sleep after N minutes idle (0 = never)
#
# Off by default. Whatever the toggle says, the screen is ALWAYS locked before
# the computer sleeps (power menu, laptop lid or the sleep timer), so waking it
# always needs your password. Game mode pauses both timers.
# Settings live in ~/.config/rice/idle.conf, so they survive reboots.

CONF="$HOME/.config/rice/idle.conf"
OUT="$HOME/.config/hypr/hypridle.conf"
GAMEMODE="${XDG_CACHE_HOME:-$HOME/.cache}/rice/gamemode"

enabled=0; lock=10; sleep=0
# shellcheck source=/dev/null
[[ -f "$CONF" ]] && source "$CONF"

save() {
    printf '# Written by idle.sh (change it from the control centre, Super+I)\nenabled=%s\nlock=%s\nsleep=%s\n' \
        "$enabled" "$lock" "$sleep" > "$CONF"
}

write_config() {
    mkdir -p "$(dirname "$OUT")"
    {
        echo "# Written by ~/.config/rice/idle.sh: change the settings from the control centre (Super+I)."
        echo "general {"
        echo "    lock_cmd = pidof hyprlock || hyprlock"
        echo "    before_sleep_cmd = loginctl lock-session"
        echo "    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'"
        echo "}"
        if [[ "$enabled" == 1 ]]; then
            echo ""
            echo "listener {"
            echo "    timeout = $(( lock * 60 ))"
            echo "    on-timeout = loginctl lock-session"
            echo "    condition_cmd = test ! -f $GAMEMODE"
            echo "}"
            if (( sleep > 0 )); then
                echo ""
                echo "listener {"
                echo "    timeout = $(( sleep * 60 ))"
                echo "    on-timeout = systemctl suspend"
                echo "    condition_cmd = test ! -f $GAMEMODE"
                echo "}"
            fi
        fi
    } > "$OUT"
}

restart() {
    command -v hypridle >/dev/null || { notify-send "Auto lock" "hypridle is not installed. Run the rice installer again."; return; }
    pkill -x hypridle 2>/dev/null
    sleep 0.2
    setsid -f hypridle >/dev/null 2>&1
}

case "${1:-}" in
    start)
        write_config; restart ;;
    toggle)
        if [[ "$enabled" == 1 ]]; then enabled=0; else enabled=1; fi
        save; write_config; restart
        if [[ "$enabled" == 1 ]]; then
            msg="Locks after $lock min idle"; (( sleep > 0 )) && msg+=", sleeps after $sleep min"
            notify-send -a "Auto lock" "Auto lock on" "$msg."
        else
            notify-send -a "Auto lock" "Auto lock off" "The screen still locks before sleep."
        fi ;;
    set)
        value="${3:-}"
        [[ "$value" =~ ^[0-9]+$ ]] || exit 1
        case "${2:-}" in
            lock)  (( value >= 1 )) && lock="$value" ;;
            sleep) sleep="$value" ;;
            *) exit 1 ;;
        esac
        save; write_config
        [[ "$enabled" == 1 ]] && restart ;;
    *)
        sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
