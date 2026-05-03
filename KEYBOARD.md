# Keyboard binding grammar

How keys are organised in this repo's WM configs (hypr, niri, and
anything that follows). Treat the modifier as a **verb**, not a bucket.

## The four layers

| Modifier      | Verb                  | Examples                                                                                              |
| ---           | ---                   | ---                                                                                                   |
| `Super`       | **focus / go to**     | `Super+h/j/k/l` focus neighbour, `Super+1-9` switch workspace, `Super+Tab` cycle, `Super+Enter` term |
| `Super+Shift` | **carry / move**      | `Super+Shift+h/j/k/l` move window, `Super+Shift+1-9` send window to workspace, `Super+Shift+Q` close |
| `Super+Ctrl`  | **adjust / resize**   | `Super+Ctrl+h/j/k/l` resize, `Super+Ctrl+arrows` nudge by pixels, `Super+Ctrl+F` fullscreen/floating |
| `Super+Alt`   | **system / meta**     | `Super+Alt+L` lock, `Super+Alt+E` exit, `Super+Alt+R` reload, screenshots, power menu                |

`Super+Shift` is *the focused thing's version of whatever Super does*.
That's why `Super+Shift+<letter>` is **not** used for app launching —
it would collide with the carry/move grammar and the i3/sway/hypr/niri
community convention.

## Launching apps

Don't burn `Super+Shift+letter` on apps. Use this hierarchy instead:

1. **Launcher** for everything → `Super+Space` (fuzzel / rofi / walker / raffi).
2. **2–3 dedicated keys** for the apps opened every minute:
   - `Super+Enter` → terminal (universal)
   - `Super+B` → browser
3. **Leader / submap** for the next tier (hyprland `submap`, niri modes):
   `Super+O` enters "open mode", then a single letter picks the app
   (`F` Firefox, `T` Thunderbird, `S` Slack, …), `Esc` exits. Neovim
   `<leader>`-style — unlimited shortcuts without consuming a modifier
   space.

## Decision rule

For any new binding, ask in order:

1. Does it move **focus**? → `Super`
2. Does it move/transform the **focused window**? → `Super+Shift`
3. Does it **resize / adjust** the focused window? → `Super+Ctrl`
4. Is it **system-level** (not tied to a window)? → `Super+Alt`
5. Is it **launching an app**? → launcher (`Super+Space`) or open-mode
   submap (`Super+O` → letter)

If the answer to all five is no, the binding probably doesn't belong at
the WM level — let the app handle it.

## Don't bind these at the WM level

- Plain `Alt+<letter>` — claimed by many TUI apps and readline.
- Plain `Ctrl+<letter>` — claimed by neovim (`Ctrl+W`, `Ctrl+R`, …),
  terminals, and shells.

`Super`-prefixed bindings are essentially conflict-free with apps;
nothing else claims `Super`. Stay inside that namespace and the WM
never steps on Neovim, emacs-style readline, or terminal mux bindings.

## In-app keyboard layer (browsers)

The WM grammar above stops at the application boundary. Inside the
browser, the equivalent layer is **Vimium**: vim-style focus,
follow-link, tab and history navigation, all on a single-letter
namespace that doesn't collide with `Super`-prefixed WM bindings.

See [`dotfiles/firefox/README.md`](dotfiles/firefox/README.md) for
install links (Firefox + Chromium) and the Backup/Restore note for
moving keybindings across browsers and machines.

## Portability between niri and hyprland

~80% of bindings port cleanly: `Super+h/j/k/l`, `Super+1-9`, `Super+Q`,
`Super+Enter`, the system layer.

The remaining ~20% must differ because the WMs differ:

- Niri uses a scrollable column model; hyprland uses tree tiling.
- Niri distinguishes columns from windows; hyprland only has windows.
- Niri's workspaces are infinite and per-monitor scrollable; hyprland's
  are numbered, per-monitor.

The grammar makes which 20% is WM-specific obvious: anything in the
*focus* or *carry* layers that touches the spatial model. Keep the
verbs the same across WMs; let the targets differ.
