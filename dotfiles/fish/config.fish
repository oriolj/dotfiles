if status is-interactive
    fastfetch
end
export PATH="$HOME/.local/bin:$PATH"

# opencode
fish_add_path /home/oriol/.opencode/bin

# aliases
alias o='opencode'
alias c='claude'
function m
    printf '\e]11;#0f2228\e\\'
    mosh minisforum-um880
    printf '\e]111\e\\'
end

# Inside kitty, route ssh through the ssh kitten so xterm-kitty terminfo
# (backspace, mouse, etc.) gets copied to the remote host on connect.
function ssh
    if set -q KITTY_WINDOW_ID
        command kitten ssh $argv
    else
        command ssh $argv
    end
end

# pnpm
set -gx PNPM_HOME "/home/oriol/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
