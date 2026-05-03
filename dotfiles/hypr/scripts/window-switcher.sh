#!/usr/bin/env bash
# Jump to any open window via fuzzel, grouped by workspace (current first)
set -euo pipefail

current_ws=$(hyprctl activeworkspace -j | jq -r '.id')

choice=$(hyprctl clients -j \
  | jq -r --argjson cur "$current_ws" '
      sort_by((.workspace.id == $cur | not), .workspace.id, .title)
      | .[]
      | select(.title != "")
      | "\(.address)|[\(.workspace.name)] \(.class) — \(.title)"
    ' \
  | fuzzel --dmenu --prompt="󱂬 " --width=80 --lines=15 \
            --with-nth=2 --nth-delimiter='|')

[[ -z "$choice" ]] && exit 0
addr="${choice%%|*}"
hyprctl dispatch focuswindow "address:$addr"
