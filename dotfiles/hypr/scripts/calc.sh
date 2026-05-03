#!/usr/bin/env bash
# Calculator: type an expression, copy the result
# Requires: libqalculate (qalc)
set -euo pipefail

if ! command -v qalc >/dev/null; then
  notify-send "Calculator" "Install libqalculate: sudo pacman -S libqalculate"
  exit 1
fi

expr=$(fuzzel --dmenu --prompt="= " --width=40 --lines=0 < /dev/null) || exit 0
[[ -z "$expr" ]] && exit 0

# -t terse, -0 no column alignment
result=$(qalc -t "$expr" 2>&1 || true)
printf "%s" "$result" | wl-copy
notify-send "= $result" "$expr   (copied)"
