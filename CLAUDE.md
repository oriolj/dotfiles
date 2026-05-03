# CLAUDE.md — dotfiles

Context for AI coding assistants working in this repository.

## What this repo is

A **public, one-way snapshot** of Oriol's personal configs from a single
Arch + Wayland workstation. Live files under `~/.config/`,
`~/.local/bin/`, and `~/` are the source of truth. This repo only holds
copies, mirrored by `sync-dotfiles.sh`.

The companion working directory at
`~/Sync/docs/claude_workdirs/hyprland/` holds the *documentation* and
notes for this setup (architecture, decisions, troubleshooting,
cheatsheets). Read its `CLAUDE.md` for the deep system context. This
repo holds the *files themselves*.

## Edit flow

1. Edit live: `~/.config/foo/foo.conf`.
2. From this repo: `./sync-dotfiles.sh snapshot`.
3. `git diff dotfiles/` → review → commit.

**Never edit files inside `dotfiles/` directly.** They will be silently
overwritten on the next `snapshot` run.

The mapping table lives in the `MAPPINGS` array at the top of
`sync-dotfiles.sh`. To track a new file, add an entry there and run
`snapshot`.

## Public-repo guardrails

This repo is public. Before adding anything to `MAPPINGS`:

- Confirm it contains no API tokens, passwords, OAuth credentials, or
  private keys. Scripts that need creds should read them at runtime
  from local files outside this repo (`syncthing.sh` and `mifi.sh` are
  the existing pattern — they `cat` a local password file).
- Confirm it doesn't snapshot a directory that may contain runtime
  cache/state/auth files (e.g., never track `~/.config/foo/` whole if
  `foo` writes session tokens there — track specific files instead).
- Personal-but-not-secret content (hostnames, locations, pinned apps,
  username paths) is acceptable and present today. If you're adding
  something new of that flavor, it's fine.

`.gitignore` carries a deny-list for known runtime/cache/credential
patterns; check it when in doubt.

## Layout

See `README.md` for the user-facing layout. In short:

- `dotfiles/<tool>/...` mirrors the relevant slice of `$HOME` for that
  tool.
- `sync-dotfiles.sh` is the only piece of imperative code at the repo
  root.

## Conventions

- **niri is the primary WM.** When the niri and hyprland configs
  diverge, niri follows niri's upstream defaults; hyprland is adapted
  to mirror. See `README.md` → "Conventions".
- **`KEYBOARD.md`** documents the binding grammar derived from niri
  defaults — consult it before suggesting any keybind change.

## Things that look weird but aren't

- `dotfiles/local-bin/*` are small Python/Bash helpers wired into bar
  widgets and keybinds. They're tracked here because they're config-ish
  glue, not application code.
- Hardcoded `/home/oriol/...` paths in scripts and configs are
  intentional — `restore` puts the files back at those paths on the
  same user's machine. If multi-user portability ever matters, the
  paths would need templating, but it currently doesn't.
- `noctalia/` snapshots the full config dir (`settings.json`,
  `colors.json`, `plugins.json`, `plugins/tailscale/`, `scripts/`).
  Noctalia regenerates `settings.json` on every change, so the diff
  will be noisy if the user touched the GUI between snapshots.

## Related

- `~/Sync/docs/claude_workdirs/hyprland/` — architecture docs and notes
  for the same setup. Read its `CLAUDE.md` for system-level context
  (compositor versions, key decisions, gotchas).
