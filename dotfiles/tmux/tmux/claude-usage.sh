#!/usr/bin/env bash
cache=/tmp/claude-usage-tmux.cache
ttl=30

if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt "$ttl" ]; then
  cat "$cache"
  exit 0
fi

out=$(claude-usage --waybar --format '5h {5h_pct}% | 7d {7d_pct}%' 2>/dev/null \
  | jq -r '.text // empty' 2>/dev/null \
  | sed -E 's#</?span[^>]*>##g')
[ -z "$out" ] && out="Claude n/a"

printf '%s\n' "$out" > "$cache"
cat "$cache"
