# Keyboard binding grammar

How keys are organised in this repo's WM configs. **niri is the primary
WM** (see `README.md` → "Conventions"), and its [upstream defaults](https://github.com/YaLTeR/niri/blob/main/resources/default-config.kdl)
define the canonical schema. hyprland is adapted to mirror it where
reasonable.

## Core rule

**Anything that controls the WM starts with `Super`** (`Mod` in niri =
`Super` on TTY). Plain `Ctrl`, `Alt`, `Shift` belong to apps —
terminals, tmux, neovim, browsers. The `Super` "tax" on every WM
binding keeps the WM out of every app's namespace.

## Layers (from niri defaults)

| Layer            | Verb                                  | Scale         | Example                                                                |
| ---              | ---                                   | ---           | ---                                                                    |
| `Mod`            | focus / act on focused window-column  | window/column | `Mod+H` focus left, `Mod+T` terminal, `Mod+V` floating, `Mod+Q` close  |
| `Mod+Shift`      | same verb at larger scale             | monitor / ws  | `Mod+Shift+H` focus monitor left, `Mod+Shift+U` move workspace down    |
| `Mod+Ctrl`       | move / send the focused thing         | window/column | `Mod+Ctrl+H` move column left, `Mod+Ctrl+1` send window to ws 1        |
| `Mod+Ctrl+Shift` | move at larger scale                  | monitor       | `Mod+Ctrl+Shift+H` move column to monitor left                         |
| `Mod+Alt`        | session / system / cross-WM parity    | global        | `Mod+Alt+L` lock, `Mod+Alt+Tab` window switcher, `Mod+Alt+N` activate-notification |

**The key pattern**: `Shift` means *"same verb, larger spatial unit"*.
Focus a column → add `Shift` → focus a monitor. Move a window → add
`Shift` → move at the column-to-monitor scale.

## Apps

niri leaves most letters in `Mod+Shift+` unbound; this repo uses them
for app launchers: `Mod+Shift+B` browser, `Mod+Shift+E` emoji,
`Mod+Shift+A` gemini, `Mod+Shift+C` calendar, `Mod+Shift+G` gmail,
`Mod+Shift+M` mosh-remote, `Mod+Shift+O` obsidian, `Mod+Shift+X` x.com.

Letters claimed by niri defaults stay as defaults — apps avoid
`Mod+Shift+H/J/K/L` (focus-monitor) and `Mod+Shift+R` (column-width-back).

Launchers proper: `Mod+Space` noctalia (primary), `Mod+Shift+Space`
raffi (curated), `Mod+D` available for niri's default fuzzel if
desired. If `Mod+Shift+<letter>` slots ever get crowded, introduce a
leader submap on a free key (e.g. `Mod+P` "Programs") for a 2-key
chord.

## Don't bind at the WM level

- Plain `Alt+<letter>` — claimed by TUI apps, readline.
- Plain `Ctrl+<letter>` — claimed by neovim, terminals, shells.

`Mod`-prefixed bindings are otherwise conflict-free with apps.

## In-app keyboard layer

The WM grammar stops at the app boundary. Inside the browser, **Vimium**
provides the equivalent vim-style layer on a single-letter namespace
that doesn't collide with `Mod`-prefixed bindings. See
[`dotfiles/firefox/README.md`](dotfiles/firefox/README.md).

## Hyprland adaptation

Hyprland's defaults differ (single-letter actions live on plain
`Super`; almost no `Super+Ctrl` use). The hyprland config in
`dotfiles/hypr/` mirrors niri's grammar where reasonable; some bindings
stay native to hyprland (`Super+Shift+1-9` for send-to-workspace,
since hyprland's example config doesn't use `Super+Ctrl` ergonomically).

Cross-mapping recipe for the spatial primitive that differs (niri
scrollable columns vs hyprland numbered workspaces) — bind the same
physical keys to the equivalent verb on each side:

- `Mod+BracketLeft/Right` — niri scroll columns / hyprland prev-next
  workspace
- `Mod+Ctrl+BracketLeft/Right` — same, carrying the focused window

Concepts that don't translate (hyprland submaps, niri column splits,
scratchpads / special workspaces, per-monitor rules, touch gestures)
stay WM-specific.
