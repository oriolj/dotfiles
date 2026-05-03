#!/usr/bin/env bash
# Noctalia CustomButton: Syncthing status.
# Outputs JSON with text/icon/tooltip/color for the noctalia CustomButton widget.

set -u

config_xml="$HOME/.config/syncthing/config.xml"

emit() {
    # Args: text icon tooltip color
    jq -cn --arg text "$1" --arg icon "$2" --arg tooltip "$3" --arg color "$4" \
        '{text: $text, icon: $icon, tooltip: $tooltip, color: $color}'
}

if ! command -v syncthing >/dev/null 2>&1; then
    emit "" "refresh-off" "Syncthing not installed" "error"
    exit 0
fi

if ! systemctl --user is-active --quiet syncthing.service; then
    emit "off" "refresh-off" $'Syncthing: stopped\nClick to start' "error"
    exit 0
fi

api_key=""
gui_addr="127.0.0.1:8384"
if [[ -r "$config_xml" ]]; then
    api_key=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "$config_xml" | head -1)
    addr=$(sed -n '/<gui /,/<\/gui>/{s:.*<address>\(.*\)</address>.*:\1:p}' "$config_xml" | head -1)
    [[ -n "$addr" ]] && gui_addr="$addr"
fi

curl_api() {
    curl -fsS --max-time 2 -H "X-API-Key: $api_key" "http://$gui_addr$1" 2>/dev/null
}

if [[ -z "$api_key" ]]; then
    emit "on" "refresh-dot" "Syncthing: running (no API key found)" "primary"
    exit 0
fi

completion=$(curl_api "/rest/db/completion")
if [[ -z "$completion" ]]; then
    emit "?" "alert-circle" "Syncthing: API not responding" "error"
    exit 0
fi

pct=$(printf '%s' "$completion" | jq -r '.completion // 100')
need_bytes=$(printf '%s' "$completion" | jq -r '.needBytes // 0')
need_items=$(printf '%s' "$completion" | jq -r '.needItems // 0')

connections=$(curl_api "/rest/system/connections")
conn_count=0
total_devs=0
if [[ -n "$connections" ]]; then
    conn_count=$(printf '%s' "$connections" | jq -r '[.connections[]? | select(.connected == true)] | length')
    total_devs=$(printf '%s' "$connections" | jq -r '.connections | length')
fi

pct_int=${pct%.*}
nl=$'\n'
if [[ "$pct_int" -ge 100 && "$need_bytes" -eq 0 ]]; then
    emit "up" "refresh-dot" "Syncthing: up to date${nl}Peers: $conn_count/$total_devs connected" "primary"
else
    emit "$pct_int%" "refresh" "Syncthing: syncing $pct_int%${nl}Items pending: $need_items${nl}Peers: $conn_count/$total_devs connected" "tertiary"
fi
