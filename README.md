# dotfiles

Personal configs for an Arch + Wayland workstation. Tracked here as a
one-way snapshot of files that live under `~/.config/`, `~/.local/bin/`,
and `~/`. The live files remain the source of truth — edit there, then
snapshot.

## Stack

- **Compositors**: **niri (primary)**, Hyprland (kept for parity).
  Configs in `dotfiles/niri/` and `dotfiles/hypr/`.
- **Bar / shell**: noctalia-shell on niri, waybar on Hyprland.
- **Terminals**: alacritty (niri), ghostty (Hyprland), kitty for floating
  popups and remote sessions.
- **Launcher**: noctalia launcher on niri, fuzzel + raffi on Hyprland.
- **Notification daemon**: mako (both compositors).
- **Shell**: fish; multiplexer: tmux.

## Conventions

- **niri is the primary WM**, and its upstream defaults are canonical.
  Hyprland is adapted to feel similar where reasonable; when the two
  diverge, niri wins and hyprland mirrors it.
- **Stick to defaults.** Customise only when there's a real reason —
  upstream defaults are the most-tested, best-documented, easiest to
  port across machines. Keep the diff against the default config small
  and explained.
- See [`KEYBOARD.md`](KEYBOARD.md) for the keybinding grammar.

## Layout

```
dotfiles/
  hypr/          hyprland.conf, hyprlock, hypridle, hyprpaper, scripts
  niri/          config.kdl
  waybar/        config.jsonc, style.css, scripts
  noctalia/      settings.json, plugins, scripts
  fuzzel/        fuzzel.ini
  raffi/         raffi.yaml (curated launcher)
  alacritty/     alacritty.toml
  chromium/      chromium-flags.conf
  fish/          config.fish, fish_plugins
  tmux/          tmux.conf + tmux/ (plugins, scripts)
  local-bin/     small helper binaries (claude-usage-noctalia, toggl-noctalia, …)
  XCompose       custom compose-key sequences
sync-dotfiles.sh  the snapshot/restore tool
```

## Snapshot / restore

```sh
./sync-dotfiles.sh snapshot          # ~/.config/... → dotfiles/...
./sync-dotfiles.sh restore           # dotfiles/...   → ~/.config/...
./sync-dotfiles.sh snapshot --dry-run
```

Mappings live in the `MAPPINGS` array at the top of `sync-dotfiles.sh`.
Directory copies use `rsync --delete`, so deletions in the source
propagate to the destination.

## Restoring on a fresh machine

```sh
git clone git@github.com:oriolj/dotfiles.git ~/git/oriolj/dotfiles
cd ~/git/oriolj/dotfiles
./sync-dotfiles.sh restore --dry-run     # preview
./sync-dotfiles.sh restore               # apply
```

The `restore` direction makes `~/.config/...` an exact mirror of
`dotfiles/...` for tracked directories. Files in `~` that are not in
this repo will be deleted for those directories — always preview first.

## What's intentionally not here

- Secrets — no API tokens, passwords, or private keys are committed.
  Scripts that need credentials (syncthing API key, tplink-m7010
  password) read them at runtime from local files outside this repo.
- SSH config and known_hosts.
- Anything under `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.local/share/...`.
- App caches and runtime state.

See `.gitignore` for the deny-list patterns the snapshot script honors.

## Notes

- See `CLAUDE.md` for project context aimed at AI coding assistants
  working in this repo.
- For wrapping a website as a desktop app, prefer
  [pake](https://github.com/tw93/Pake) over `chromium --app=URL`. Pake
  builds a real native window (Tauri/Rust) instead of a stripped-down
  browser shell. The keyboard-bound web apps (gemini, gcal, gmail,
  claude, chatgpt, gkeep, ha, x) are declared in `build-pake-apps.sh`,
  which generates a per-app PKGBUILD, builds it via pake-cli, and
  installs to `/usr/bin/<name>-app` via pacman. Run
  `./build-pake-apps.sh --list` to see the set; `./build-pake-apps.sh`
  to build the missing ones (~5–10 min per app, first run).
- The noctalia control center (notifications, power profile, keep
  awake, night light, audio, brightness, weather, …) is opened by
  **right-clicking anywhere on the bar** (`bar.rightClickAction =
  controlCenter` in `noctalia/settings.json`). The Noctalia logo
  widget is intentionally not in the bar — the right-click is
  enough.
- The noctalia bar shows disk **usage** (`/`) as a percent, with warning
  at 70% and critical at 85% (`systemMonitor.diskWarningThreshold` /
  `diskCriticalThreshold` in `noctalia/settings.json`). Lower than the
  noctalia defaults (80/90) because `/` is btrfs and wants headroom to
  stay performant — once free space drops too low, allocation and
  balance get expensive.
