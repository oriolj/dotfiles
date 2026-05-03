#!/usr/bin/env bash
# Snapshot live dotfiles into this repo (or restore them from the repo).
# Edit the MAPPINGS table below to add/remove tracked files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$SCRIPT_DIR/dotfiles"

# "<absolute source under $HOME>|<relative destination under dotfiles/>"
# Directory entries are mirrored exactly (rsync --delete).
declare -a MAPPINGS=(
    "$HOME/.config/hypr/hyprland.conf|hypr/hyprland.conf"
    "$HOME/.config/hypr/hyprlock.conf|hypr/hyprlock.conf"
    "$HOME/.config/hypr/hypridle.conf|hypr/hypridle.conf"
    "$HOME/.config/hypr/hyprpaper.conf|hypr/hyprpaper.conf"
    "$HOME/.config/hypr/scripts|hypr/scripts"
    "$HOME/.config/niri/config.kdl|niri/config.kdl"
    "$HOME/.config/waybar/config.jsonc|waybar/config.jsonc"
    "$HOME/.config/waybar/style.css|waybar/style.css"
    "$HOME/.config/waybar/scripts|waybar/scripts"
    "$HOME/.config/fuzzel/fuzzel.ini|fuzzel/fuzzel.ini"
    "$HOME/.config/raffi/raffi.yaml|raffi/raffi.yaml"
    "$HOME/.config/alacritty/alacritty.toml|alacritty/alacritty.toml"
    "$HOME/.config/chromium-flags.conf|chromium/chromium-flags.conf"
    "$HOME/.config/fish/config.fish|fish/config.fish"
    "$HOME/.config/fish/fish_plugins|fish/fish_plugins"
    "$HOME/.config/fish/functions/tm.fish|fish/functions/tm.fish"
    "$HOME/.claude/CLAUDE.md|claude/CLAUDE.md"
    "$HOME/.claude/statusline-command.sh|claude/statusline-command.sh"
    "$HOME/.config/noctalia|noctalia"
    "$HOME/.local/bin/claude-usage-noctalia|local-bin/claude-usage-noctalia"
    "$HOME/.local/bin/battery-watts|local-bin/battery-watts"
    "$HOME/.local/bin/toggl-noctalia|local-bin/toggl-noctalia"
    "$HOME/.local/bin/notification-activate|local-bin/notification-activate"
    "$HOME/.XCompose|XCompose"
    "$HOME/.tmux.conf|tmux/tmux.conf"
    "$HOME/.tmux|tmux/tmux"
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [snapshot|restore] [--dry-run]

  snapshot   (default) copy \$HOME → $DOTFILES/  — for committing changes.
  restore    copy $DOTFILES/ → \$HOME           — e.g. on a fresh machine.
  --dry-run  preview without writing anything.

Sources/destinations are hard-coded in MAPPINGS at the top of this script.
Directory copies use rsync --delete: the destination is made an exact mirror
of the source. With \`restore\`, files in \$HOME not in the repo will be
removed for tracked directories — preview with --dry-run first.
EOF
}

MODE="snapshot"
DRY=()

while (( $# )); do
    case "$1" in
        snapshot|restore) MODE="$1" ;;
        -n|--dry-run) DRY=(--dry-run) ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

command -v rsync >/dev/null || { echo "rsync is required" >&2; exit 1; }

copied=0
skipped=0
for entry in "${MAPPINGS[@]}"; do
    src_home="${entry%%|*}"
    dst_rel="${entry##*|}"
    dst_repo="$DOTFILES/$dst_rel"

    if [[ "$MODE" == "snapshot" ]]; then
        from="$src_home"; to="$dst_repo"
    else
        from="$dst_repo"; to="$src_home"
    fi

    if [[ ! -e "$from" ]]; then
        echo "skip: $from (missing)"
        ((++skipped))
        continue
    fi

    if [[ -d "$from" ]]; then
        mkdir -p "$to"
        rsync -a --delete "${DRY[@]}" "$from/" "$to/"
    else
        mkdir -p "$(dirname "$to")"
        rsync -a "${DRY[@]}" "$from" "$to"
    fi
    printf '%s: %s -> %s\n' "$MODE" "$from" "$to"
    ((++copied))
done

echo
echo "$MODE complete: $copied copied, $skipped skipped"
if [[ "$MODE" == "snapshot" && ${#DRY[@]} -eq 0 ]]; then
    echo "Next: review with 'git status' / 'git diff dotfiles/' and commit."
fi
