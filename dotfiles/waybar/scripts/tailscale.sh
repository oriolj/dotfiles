#!/usr/bin/env bash
# Waybar module: Tailscale status.
# Outputs JSON with text/tooltip/class for the waybar custom module.

set -u

if ! command -v tailscale >/dev/null 2>&1; then
    exit 0
fi

status_json=$(tailscale status --json 2>/dev/null) || {
    printf '{"text":"TS ?","tooltip":"tailscale: cannot query status","class":"error"}\n'
    exit 0
}

nl=$'\n'

backend=$(printf '%s' "$status_json" | jq -r '.BackendState // "Unknown"')

case "$backend" in
    Running)
        self_ip=$(printf '%s' "$status_json" | jq -r '.Self.TailscaleIPs[0] // "?"')
        self_name=$(printf '%s' "$status_json" | jq -r '.Self.HostName // "?"')
        exit_node=$(printf '%s' "$status_json" | jq -r '[.Peer[]? | select(.ExitNode == true) | .HostName] | first // ""')
        peer_online=$(printf '%s' "$status_json" | jq -r '[.Peer[]? | select(.Online == true)] | length')
        peer_total=$(printf '%s' "$status_json" | jq -r '[.Peer[]?] | length')

        if [[ -n "$exit_node" ]]; then
            text="󰖂 $exit_node"
            class="exit-node"
        else
            text="󰖂 on"
            class="connected"
        fi

        tooltip="Tailscale: Running${nl}Host: $self_name ($self_ip)${nl}Peers online: $peer_online/$peer_total"
        [[ -n "$exit_node" ]] && tooltip="$tooltip${nl}Exit node: $exit_node"
        ;;
    Stopped)
        text="󰖂 off"
        class="stopped"
        tooltip="Tailscale: Stopped${nl}Click to start"
        ;;
    NeedsLogin|NoState)
        text="󰖂 login"
        class="needs-login"
        tooltip="Tailscale: needs login${nl}Run: tailscale up"
        ;;
    *)
        text="󰖂 $backend"
        class="unknown"
        tooltip="Tailscale: $backend"
        ;;
esac

jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class, alt: $class}'
