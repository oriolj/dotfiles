#!/usr/bin/env bash
# Adjust the focused output's scale.
# Usage: output-scale.sh <delta|=value>
#   output-scale.sh +0.1   -> increase by 0.1
#   output-scale.sh -0.1   -> decrease by 0.1
#   output-scale.sh =1.0   -> set to 1.0

set -euo pipefail

arg=${1:?"usage: $0 <+0.1|-0.1|=1.0>"}

read -r name current < <(
    niri msg --json focused-output \
    | jq -r '"\(.name) \(.logical.scale)"'
)

case "$arg" in
    =*) new=${arg#=} ;;
    *)  new=$(awk -v c="$current" -v d="$arg" 'BEGIN { printf "%.2f", c + d }') ;;
esac

# Clamp to a sane range.
new=$(awk -v n="$new" 'BEGIN {
    if (n < 0.5) n = 0.5
    if (n > 3.0) n = 3.0
    printf "%.2f", n
}')

niri msg output "$name" scale "$new"

old=$(awk -v c="$current" 'BEGIN { printf "%.2f", c }')
notify-send -a "niri" -h string:x-canonical-private-synchronous:output-scale \
    "Monitor scale" "$name: ${old}× → ${new}×"
