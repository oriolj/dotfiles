function tm --description 'Jump into tmux choose-tree session picker'
    if set -q TMUX
        tmux choose-tree -Zs
    else if tmux has-session 2>/dev/null
        tmux attach \; choose-tree -Zs
    else
        tmux new-session
    end
end
