#!/bin/sh
tmux list-sessions -F '#{session_id} #{session_name}' 2>/dev/null | while read sid sname; do
    color=$(~/.tmux/session-color.sh "$sname")
    tmux set -t "$sid" @bg-color "$color"
done
