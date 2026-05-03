#!/usr/bin/env bash
# Host launcher: pick a host from ~/.ssh/config, connect via ssh (default) or mosh.
#
# Opt into mosh per host by adding `# mosh` as a comment on the Host line:
#   Host minisforum  # mosh
#     HostName minisforum-um880
#
# Hosts with a `RemoteCommand` directive always use ssh (mosh can't run it).
set -euo pipefail

CONFIG="$HOME/.ssh/config"
[[ -f "$CONFIG" ]] || { notify-send "Host launcher" "No ~/.ssh/config found"; exit 1; }

entries=$(awk '
  function flush() {
    if (host != "") {
      mode = (use_mosh && !has_remote_cmd) ? "mosh" : "ssh"
      print host "\t" mode
    }
    host = ""; use_mosh = 0; has_remote_cmd = 0
  }
  tolower($1) == "host" {
    flush()
    for (i = 2; i <= NF; i++) {
      if ($i ~ /^#/) break
      if ($i ~ /[*?]/) continue
      host = $i
      break
    }
    if ($0 ~ /#[[:space:]]*mosh\>/) use_mosh = 1
  }
  host != "" && /#[[:space:]]*mosh\>/ { use_mosh = 1 }
  host != "" && tolower($1) == "remotecommand" { has_remote_cmd = 1 }
  END { flush() }
' "$CONFIG" | sort -u)

[[ -z "$entries" ]] && { notify-send "Host launcher" "No hosts in ~/.ssh/config"; exit 1; }

choice=$(printf "%s\n" "$entries" \
  | awk -F'\t' '{ printf "%s|%-20s  (%s)\n", $1, $1, $2 }' \
  | fuzzel --dmenu --prompt=" " --width=40 --lines=10 \
           --with-nth=2 --nth-delimiter='|') || exit 0

[[ -z "$choice" ]] && exit 0
host="${choice%%|*}"
mode=$(printf "%s\n" "$entries" | awk -F'\t' -v h="$host" '$1 == h { print $2; exit }')

actual_mode="ssh"
if [[ "$mode" == "mosh" ]] && command -v mosh >/dev/null; then
  actual_mode="mosh"
fi

# Distinctive visual cues for remote sessions: custom class (for Hyprland border rule),
# title, and a dark-red-tinted background so you can't miss that you're not local.
ghostty \
  --class=com.mitchellh.ghostty.remote \
  --title="$actual_mode $host" \
  --background=#2a1010 \
  -e "$actual_mode" "$host"
