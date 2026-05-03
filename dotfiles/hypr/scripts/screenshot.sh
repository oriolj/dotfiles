#!/usr/bin/env bash
# Omarchy-inspired screenshot wrapper.
# Modes: region (default), window, fullscreen, smart
# Pipes capture into satty for annotation; saves to ~/Pictures and clipboard.

set -euo pipefail

MODE="${1:-region}"
OUT_DIR="${OMARCHY_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"
mkdir -p "$OUT_DIR"
FILE="$OUT_DIR/screenshot-$(date +%Y%m%d-%H%M%S).png"

geom=""
case "$MODE" in
    region)
        geom="$(slurp -d)" || exit 0
        ;;
    window)
        active_ws="$(hyprctl -j activeworkspace | jq -r '.id')"
        geom="$(hyprctl -j clients \
            | jq -r --argjson ws "$active_ws" \
                '.[] | select(.workspace.id == $ws) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' \
            | slurp)" || exit 0
        ;;
    fullscreen)
        geom="$(hyprctl -j monitors \
            | jq -r '.[] | select(.focused) | "\(.x),\(.y) \(.width)x\(.height)"')"
        ;;
    smart)
        geom="$(slurp -d)" || exit 0
        ;;
    *)
        echo "usage: screenshot.sh [region|window|fullscreen|smart]" >&2
        exit 2
        ;;
esac

grim -g "$geom" - \
    | satty --filename - \
            --output-filename "$FILE" \
            --early-exit \
            --copy-command wl-copy \
            --actions-on-enter save-to-clipboard \
            --initial-tool brush
