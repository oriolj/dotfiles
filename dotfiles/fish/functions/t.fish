function t --description 'tmux session named after the current dir (create or attach)'
    # tmux disallows '.' and ':' in session names — sanitise them.
    set -l name (string replace -a -r '[.:]' '_' (basename $PWD))
    if set -q TMUX
        tmux new-session -d -s $name -c $PWD 2>/dev/null
        tmux switch-client -t $name
    else
        tmux new-session -A -s $name -c $PWD
    end
end
