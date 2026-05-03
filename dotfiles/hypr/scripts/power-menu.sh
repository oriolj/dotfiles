#!/usr/bin/env bash
# Power menu via fuzzel --dmenu
set -euo pipefail

choice=$(printf "%s\n" \
  " Lock" \
  "󰍃 Logout" \
  "󰒲 Suspend" \
  " Reboot" \
  " Shutdown" \
  | fuzzel --dmenu --prompt="⏻ " --lines=5 --width=20)

case "${choice##* }" in
  Lock)     hyprlock ;;
  Logout)   hyprctl dispatch exit ;;
  Suspend)  systemctl suspend ;;
  Reboot)   systemctl reboot ;;
  Shutdown) systemctl poweroff ;;
esac
