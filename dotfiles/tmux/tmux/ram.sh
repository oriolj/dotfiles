#!/bin/sh
# Prints "RAM% (SWAP%)" for the tmux status bar.
# Colours each value: black (normal) → orange (warn) → red (high).
awk '
function col(p, warn, hi) {
    if (p >= hi)   return "#[fg=#ef4444]"
    if (p >= warn) return "#[fg=#fb923c]"
    return "#[fg=#000000]"
}
/MemTotal/{t=$2}
/MemAvailable/{a=$2}
/SwapTotal/{st=$2}
/SwapFree/{sf=$2}
END {
    r = (t-a)/t*100
    s = (st>0) ? (st-sf)/st*100 : 0
    printf "%s%.0f%%#[fg=#000000] (%s%.0f%%#[fg=#000000])\n", col(r,75,90), r, col(s,50,80), s
}
' /proc/meminfo
