#!/usr/bin/env bash
# Show icon only when mako is in do-not-disturb mode.
# Click toggles DND.

if makoctl mode 2>/dev/null | grep -qx "do-not-disturb"; then
    printf '{"text":"󰂛","tooltip":"Do Not Disturb is ON\\nClick to disable","class":"dnd-on"}\n'
else
    printf '{"text":"","tooltip":"","class":"dnd-off"}\n'
fi
