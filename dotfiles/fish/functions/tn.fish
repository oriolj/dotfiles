function tn --description 'Join the current dir tmux session via a grouped (independent) client'
    # tmux disallows '.' and ':' in session names — sanitise them.
    set -l name (string replace -a -r '[.:]' '_' (basename $PWD))
    if tmux has-session -t $name 2>/dev/null
        # Grouped session: shares windows/panes but navigates independently;
        # destroyed once this client detaches.
        tmux new-session -t $name \; set-option destroy-unattached on
    else
        tmux new-session -A -s $name -c $PWD
    end
end
