#!/usr/bin/env bash
cache=/tmp/claude-usage-tmux.cache
ttl=30

if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt "$ttl" ]; then
  cat "$cache"
  exit 0
fi

out=$(claude-usage --waybar --format '{icon_plain} {5h_pct}% {5h_reset} | {7d_pct}% {7d_reset}' 2>/dev/null \
  | jq -r '.text // empty' 2>/dev/null \
  | sed -E 's#</?span[^>]*>##g')
[ -z "$out" ] && out="n/a"

printf '%s\n' "$out" > "$cache"
cat "$cache"
