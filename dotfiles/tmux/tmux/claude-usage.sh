#!/usr/bin/env bash
# Tmux status widget for `claude-usage`. Caches the result for $ttl seconds.
#
# claude-usage is a passive cookie reader: it reads the claude.ai session
# cookie out of the browser's cookie DB and calls the usage API. A 401/403
# ("Auth Err") means that cookie is stale. The only thing that refreshes it
# is the browser loading claude.ai (which rotates the cookie back into the
# DB), so on Auth Err we open claude.ai in Chromium to try to renew —
# but at most $max_attempts times. After that we stop (so we don't spawn a
# tab every poll forever) and show "🔑 claude login needed (Chromium)" until
# a successful read resets the counter.
#
# We keep a no-op xdg-open shim on PATH so claude-usage's *own* unbounded
# login-page launch never fires; the bounded open below is the only one.
cache=/tmp/claude-usage-tmux.cache
last_good=/tmp/claude-usage-tmux.last
authfails=/tmp/claude-usage-tmux.authfails
ttl=30
max_attempts=3
browser=chromium
browser_label=Chromium
login_url=https://claude.ai

if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt "$ttl" ]; then
  cat "$cache"
  exit 0
fi

# No-op xdg-open shim so claude-usage can't hijack the screen on its own;
# the bounded open in this script is the only intended browser launch.
shim_dir=/tmp/claude-usage-tmux-shim
if [ ! -x "$shim_dir/xdg-open" ]; then
  mkdir -p "$shim_dir"
  printf '#!/bin/sh\nexit 0\n' > "$shim_dir/xdg-open"
  chmod +x "$shim_dir/xdg-open"
fi
export PATH="$shim_dir:$PATH"

out=$(claude-usage --waybar --browser "$browser" --format '{icon_plain} {5h_pct}% {5h_reset} | {7d_pct}% {7d_reset}' 2>/dev/null \
  | jq -r '.text // empty' 2>/dev/null \
  | sed -E 's#</?span[^>]*>##g')

if [ -n "$out" ] && [[ "$out" != *"Err"* ]]; then
  # Success — cache it and reset the auth-failure counter.
  printf '%s\n' "$out" | tee "$last_good" > "$cache"
  rm -f "$authfails"
elif [[ "$out" == *"Auth Err"* ]]; then
  n=$(cat "$authfails" 2>/dev/null || echo 0)
  if [ "$n" -lt "$max_attempts" ]; then
    n=$((n + 1))
    printf '%s\n' "$n" > "$authfails"
    # Detached, bounded attempt to refresh the cookie in the real browser.
    setsid -f "$browser" "$login_url" >/dev/null 2>&1 || \
      ( "$browser" "$login_url" >/dev/null 2>&1 & )
    printf '🔄 claude renew %s/%s\n' "$n" "$max_attempts" > "$cache"
  else
    printf '🔑 claude login needed (%s)\n' "$browser_label" > "$cache"
  fi
elif [ -s "$last_good" ]; then
  # Non-auth error (e.g. network) — keep the last good value with a warning.
  printf '⚠ %s\n' "$(cat "$last_good")" > "$cache"
else
  printf 'n/a\n' > "$cache"
fi

cat "$cache"
