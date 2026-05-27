if status is-interactive
    fastfetch
end
export PATH="$HOME/.local/bin:$PATH"

# opencode
fish_add_path /home/oriol/.opencode/bin

# aliases
function o
    if not set -q TMUX
        echo "o: refusing to run opencode outside tmux. Start/attach a tmux session first." >&2
        return 1
    end
    command opencode $argv
end
function c
    if not set -q TMUX
        echo "c: refusing to run claude outside tmux. Start/attach a tmux session first." >&2
        return 1
    end
    command claude $argv
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
