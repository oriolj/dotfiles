#!/usr/bin/env bash
# Show icon only when idle is INHIBITED (hypridle not running).
# Click toggles hypridle on/off.

if pgrep -x hypridle >/dev/null; then
    # hypridle running → idle behavior active → show nothing
    echo '{"text": "", "tooltip": "", "class": "idle-active"}'
else
    # hypridle killed → idle inhibited → show indicator
    echo '{"text": "󰛐", "tooltip": "Idle inhibited (hypridle stopped)\\nClick to re-enable", "class": "idle-inhibited"}'
fi
