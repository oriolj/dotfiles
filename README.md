# dotfiles

Personal configs for an Arch + Wayland workstation. Tracked here as a
one-way snapshot of files that live under `~/.config/`, `~/.local/bin/`,
and `~/`. The live files remain the source of truth — edit there, then
snapshot.

## Stack

- **Compositors**: Hyprland and niri (both daily-driven; configs in
  `dotfiles/hypr/` and `dotfiles/niri/`).
- **Bar / shell**: waybar on Hyprland, noctalia-shell on niri.
- **Terminals**: ghostty (Hyprland), alacritty (niri), kitty for floating
  popups and remote sessions.
- **Launcher**: fuzzel + raffi on Hyprland, noctalia launcher on niri.
- **Notification daemon**: mako (both compositors).
- **Shell**: fish; multiplexer: tmux.

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
