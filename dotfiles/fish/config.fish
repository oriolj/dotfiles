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
