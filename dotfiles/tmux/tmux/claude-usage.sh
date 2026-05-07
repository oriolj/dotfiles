#!/usr/bin/env bash
# Tmux status widget for `claude-usage`. Caches the result for $ttl seconds,
# and on auth/fetch errors falls back to the last successful value with a
# `⚠ ` prefix so the bar keeps something useful instead of "Auth Err".
cache=/tmp/claude-usage-tmux.cache
last_good=/tmp/claude-usage-tmux.last
ttl=30

if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt "$ttl" ]; then
  cat "$cache"
  exit 0
fi

out=$(claude-usage --waybar --format '{icon_plain} {5h_pct}% {5h_reset} | {7d_pct}% {7d_reset}' 2>/dev/null \
  | jq -r '.text // empty' 2>/dev/null \
  | sed -E 's#</?span[^>]*>##g')

if [ -n "$out" ] && [[ "$out" != *"Err"* ]]; then
  printf '%s\n' "$out" | tee "$last_good" > "$cache"
elif [ -s "$last_good" ]; then
  printf '⚠ %s\n' "$(cat "$last_good")" > "$cache"
else
  printf 'n/a\n' > "$cache"
fi

cat "$cache"
