# claude-ps

Counts running **Claude Code** sessions on this machine and classifies each
as **working** (agent busy — terminal title shows a braille spinner) or
**waiting** (idle at the prompt — title shows Claude's `✳` marker).

Unlike the single-file scripts elsewhere in `local-bin/`, this is a compiled
Go tool: **the source here is the source of truth**, and the binary is built
out to `~/.local/bin/`. It is therefore *not* mirrored by `sync-dotfiles.sh`
(no `MAPPINGS` entry); rebuild it after editing instead.

## Build

```sh
make install      # go build -> ~/.local/bin/claude-ps
make run          # build + run (human-readable)
```

## Usage

```sh
claude-ps             # summary + per-session list (working first)
claude-ps --watch     # live-refreshing monitor (alt-screen, every 2s)
claude-ps --count     # just the total number
claude-ps --tmux      # compact one-liner: "🔄 2 ✅ 18"
claude-ps --json      # counts + per-session detail
claude-ps --noctalia  # JSON for the Noctalia CustomButton widget
```

## How working-vs-waiting is detected

Each session PID (`/proc/<pid>/comm == "claude"`) is mapped to its
pseudo-terminal, then to the matching **tmux pane title** — the same signal
the tmux status bar uses (`dotfiles/tmux/tmux.conf`, `@agent-state`). A
leading braille spinner ⇒ working; a `✳…` or plain-path title ⇒ waiting.
Sessions whose tty isn't a visible tmux pane (run outside tmux) are counted
but reported as `unknown` state.

## Noctalia bar widget

A `CustomButton` (`ipcIdentifier: claudeSessions`) in
`noctalia/settings.json` runs `claude-ps --noctalia` every 5 s. The bar
shows `working/total` (e.g. `2/20`); the tooltip lists every session.

**Left-click** opens a floating ghostty (`com.mitchellh.ghostty.claude-ps`)
running `claude-ps --watch` — a live monitor. Float window-rules live in
`niri/config.kdl` and `hypr/hyprland.conf`.

## tmux status bar

The second status line (`tmux/tmux.conf`, `status-format[1]`) includes a
`🤖 #(claude-ps --tmux)` segment next to the CPU/RAM/Disk/🐳 readouts,
refreshing on the 2 s `status-interval`. (This is the machine-wide count;
the per-window `🔄`/`✅` emoji from `@agent-state` is a separate, per-pane
signal.)
