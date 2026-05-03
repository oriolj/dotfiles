#!/bin/sh
state=/tmp/tmux-cpu-state.$USER
read cpu a b c idle rest < /proc/stat
total=$((a+b+c+idle))
now=$(date +%s)

if [ -f "$state" ]; then
    . "$state"
    age=$((now - prev_ts))
    if [ "$age" -ge 5 ]; then
        dt=$((total - prev_total))
        di=$((idle - prev_idle))
        [ "$dt" -gt 0 ] && last_pct=$(( (dt - di) * 100 / dt ))
        prev_total=$total
        prev_idle=$idle
        prev_ts=$now
    fi
else
    last_pct=0
    prev_total=$total
    prev_idle=$idle
    prev_ts=$now
fi

load=$(awk '{print $3}' /proc/loadavg)
printf "%d%% (%s)\n" "${last_pct:-0}" "$load"

cat > "$state" <<EOF
prev_total=$prev_total
prev_idle=$prev_idle
prev_ts=$prev_ts
last_pct=${last_pct:-0}
EOF
