#!/usr/bin/env bash
# Install Brave managed policies into /etc/brave/policies/managed/.
# Disables Wallet, VPN, Leo AI chat, and Rewards system-wide.
# Idempotent — safe to re-run. Restart Brave afterwards; verify at
# brave://policy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/policies.json"
DST_DIR="/etc/brave/policies/managed"
DST="$DST_DIR/policies.json"

[[ -f "$SRC" ]] || { echo "missing source: $SRC" >&2; exit 1; }

echo "Installing Brave policies → $DST (requires sudo)"
sudo install -d -m 0755 "$DST_DIR"
sudo install -m 0644 "$SRC" "$DST"

echo "Done. Restart Brave and verify at brave://policy"
