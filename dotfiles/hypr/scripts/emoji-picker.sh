#!/usr/bin/env bash
# Emoji picker: pick from a curated list.
# Default: copy to clipboard.
# If `wtype` is installed, also type into the focused field.
set -euo pipefail

LIST="$(dirname "$(readlink -f "$0")")/emoji-list.txt"

picked=$(fuzzel --dmenu --prompt="😀 " --width=50 --lines=15 < "$LIST") || exit 0
emoji="${picked%% *}"

printf "%s" "$emoji" | wl-copy
if command -v wtype >/dev/null; then
  wtype -- "$emoji" 2>/dev/null || true
fi
notify-send "Emoji: $emoji" "${picked#* }  (copied)"
