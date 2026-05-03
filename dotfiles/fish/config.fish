if status is-interactive
    # Commands to run in interactive sessions can go here
    if test "$SHLVL" = 1
        fastfetch
    end
end

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

# pnpm
set -gx PNPM_HOME "/home/oriol/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
