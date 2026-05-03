#!/bin/bash
temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
if [ -n "$temp" ]; then
    echo "$((temp / 1000))°C"
else
    echo "N/A"
fi
