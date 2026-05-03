#!/usr/bin/env bash
# Waybar module: Syncthing status.
# Outputs JSON with text/tooltip/class for the waybar custom module.

set -u

config_xml="$HOME/.config/syncthing/config.xml"

if ! command -v syncthing >/dev/null 2>&1; then
    exit 0
fi

if ! systemctl --user is-active --quiet syncthing.service; then
    printf '{"text":"󰓦 off","tooltip":"Syncthing: stopped\nClick to start","class":"stopped"}\n'
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
    jq -cn '{text:"󰓦 on", tooltip:"Syncthing: running (no API key found)", class:"connected"}'
    exit 0
fi

completion=$(curl_api "/rest/db/completion")
if [[ -z "$completion" ]]; then
    jq -cn '{text:"󰓦 ?", tooltip:"Syncthing: API not responding", class:"error"}'
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
    text="󰓦 up"
    class="idle"
    tooltip="Syncthing: up to date${nl}Peers: $conn_count/$total_devs connected"
else
    text="󰓦 $pct_int%"
    class="syncing"
    tooltip="Syncthing: syncing $pct_int%${nl}Items pending: $need_items${nl}Peers: $conn_count/$total_devs connected"
fi

jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class, alt: $class}'
