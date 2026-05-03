#!/usr/bin/env bash
# Generate one .desktop file per host in ~/.ssh/config so they appear in
# fuzzel's app launcher (searchable as "ssh <host>").
# Re-run whenever ~/.ssh/config changes. Called from exec-once in hyprland.conf.
set -euo pipefail

CONFIG="$HOME/.ssh/config"
OUT_DIR="$HOME/.local/share/applications"
PREFIX="ssh-"

[[ -f "$CONFIG" ]] || exit 0
mkdir -p "$OUT_DIR"

# Wipe old generated entries
find "$OUT_DIR" -maxdepth 1 -name "${PREFIX}*.desktop" -delete

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
' "$CONFIG")

while IFS=$'\t' read -r host mode; do
  [[ -z "$host" ]] && continue
  cat > "$OUT_DIR/${PREFIX}${host}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=SSH: $host
GenericName=Remote shell ($mode)
Comment=Connect to $host via $mode
Exec=kitty --class=kitty-remote-prod --title=${mode}\\ ${host} -o background=#2a1010 $mode $host
Icon=utilities-terminal
Terminal=false
Categories=Network;RemoteAccess;
Keywords=ssh;mosh;remote;shell;$host;
EOF
done <<< "$entries"
