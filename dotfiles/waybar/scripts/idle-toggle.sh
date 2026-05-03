#!/usr/bin/env bash
# Toggle hypridle on/off. Paired with idle-inhibit.sh waybar module.

if pgrep -x hypridle >/dev/null; then
    pkill -x hypridle
    notify-send "Idle inhibited" "Screen will not sleep" -i system-lock-screen
else
    hypridle &
    disown
    notify-send "Idle active" "Normal sleep/lock timers" -i system-suspend
fi

# Refresh the waybar module immediately
pkill -RTMIN+8 waybar
