#!/usr/bin/env bash
# Tmux status widget for `claude-usage`. Caches the result for $ttl seconds,
# and on auth/fetch errors falls back to the last successful value with a
# `⚠ ` prefix so the bar keeps something useful instead of "Auth Err".
#
# `claude-usage` opens the Claude login page (xdg-open) on a 401/403 — which
# from a status bar polling every $ttl seconds means the browser keeps popping
# up. We don't want that: shim `xdg-open` to a no-op for this invocation so the
# launch becomes a silent exit, and surface "🔑 claude login needed" on the bar
# instead.
cache=/tmp/claude-usage-tmux.cache
last_good=/tmp/claude-usage-tmux.last
ttl=30

if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt "$ttl" ]; then
  cat "$cache"
  exit 0
fi

# No-op xdg-open shim so claude-usage can't hijack the screen with the login
# page. Prepended to PATH only for this script's subprocesses.
shim_dir=/tmp/claude-usage-tmux-shim
if [ ! -x "$shim_dir/xdg-open" ]; then
  mkdir -p "$shim_dir"
  printf '#!/bin/sh\nexit 0\n' > "$shim_dir/xdg-open"
  chmod +x "$shim_dir/xdg-open"
fi
export PATH="$shim_dir:$PATH"

out=$(claude-usage --waybar --format '{icon_plain} {5h_pct}% {5h_reset} | {7d_pct}% {7d_reset}' 2>/dev/null \
  | jq -r '.text // empty' 2>/dev/null \
  | sed -E 's#</?span[^>]*>##g')

if [ -n "$out" ] && [[ "$out" != *"Err"* ]]; then
  printf '%s\n' "$out" | tee "$last_good" > "$cache"
elif [[ "$out" == *"Auth Err"* ]]; then
  printf '🔑 claude login needed\n' > "$cache"
elif [ -s "$last_good" ]; then
  printf '⚠ %s\n' "$(cat "$last_good")" > "$cache"
else
  printf 'n/a\n' > "$cache"
fi

cat "$cache"
