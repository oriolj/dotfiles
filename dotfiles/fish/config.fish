if status is-interactive
    # Only greet in the top-level shell, not nested subshells.
    if test "$SHLVL" = 1
        fastfetch
    end
end
export PATH="$HOME/.local/bin:$PATH"

# opencode
fish_add_path /home/oriol/.opencode/bin

# aliases
function o
    if set -q TMUX
        command opencode $argv
        return
    end
    # Outside tmux: behave like `t` then `o` — create/attach the dir's session
    # and launch opencode inside a freshly-created one.
    set -l name (string replace -a -r '[.:]' '_' (basename $PWD))
    if tmux new-session -d -s $name -c $PWD 2>/dev/null
        tmux send-keys -t $name "opencode $argv" Enter
    end
    tmux attach -t $name
end
function on
    if set -q TMUX
        command opencode $argv
        return
    end
    # tn-style: ensure the dir's session exists (launch opencode in a fresh one),
    # then join it via a grouped, independently-navigable client.
    set -l name (string replace -a -r '[.:]' '_' (basename $PWD))
    if tmux new-session -d -s $name -c $PWD 2>/dev/null
        tmux send-keys -t $name "opencode $argv" Enter
    end
    tmux new-session -t $name \; set-option destroy-unattached on
end
function c
    if set -q TMUX
        command claude $argv
        return
    end
    # Outside tmux: behave like `t` then `c` — create/attach the dir's session
    # and launch claude inside a freshly-created one.
    set -l name (string replace -a -r '[.:]' '_' (basename $PWD))
    if tmux new-session -d -s $name -c $PWD 2>/dev/null
        tmux send-keys -t $name "claude $argv" Enter
    end
    tmux attach -t $name
end
function cn
    if set -q TMUX
        command claude $argv
        return
    end
    # tn-style: ensure the dir's session exists (launch claude in a fresh one),
    # then join it via a grouped, independently-navigable client.
    set -l name (string replace -a -r '[.:]' '_' (basename $PWD))
    if tmux new-session -d -s $name -c $PWD 2>/dev/null
        tmux send-keys -t $name "claude $argv" Enter
    end
    tmux new-session -t $name \; set-option destroy-unattached on
end
# Remote sessions tint the terminal background so it's obvious at a glance
# that input isn't going to the local box. OSC 11 sets the background; OSC 111
# resets it to the configured default when the session ends.
#   minisforum (home server) → dark teal #0f2228
#   any other host           → dark maroon #2a1212
function m
    printf '\e]11;#0f2228\e\\'
    mosh minisforum-um880
    printf '\e]111\e\\'
end

# Inside kitty, route ssh through the ssh kitten so xterm-kitty terminfo
# (backspace, mouse, etc.) gets copied to the remote host on connect.
function ssh
    printf '\e]11;#2a1212\e\\'
    if set -q KITTY_WINDOW_ID
        command kitten ssh $argv
    else
        command ssh $argv
    end
    printf '\e]111\e\\'
end

# pnpm
set -gx PNPM_HOME "/home/oriol/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
