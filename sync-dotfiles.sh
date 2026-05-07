#!/usr/bin/env bash
# Snapshot live dotfiles into this repo (or restore them onto the host).
# Edit the MAPPINGS table below to add/remove tracked files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$SCRIPT_DIR/dotfiles"

# "<absolute source under $HOME>|<relative destination under dotfiles/>"
# Group names in the picker are derived from the first segment of the
# destination path (e.g. "hypr/scripts" → group "hypr").
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
    "$HOME/.config/kitty/kitty.conf|kitty/kitty.conf"
    "$HOME/.config/ghostty/config|ghostty/config"
    "$HOME/.ssh/config.d/term.conf|ssh/config.d/term.conf"
    "$HOME/.config/fastfetch/config.jsonc|fastfetch/config.jsonc"
    "$HOME/.config/chromium-flags.conf|chromium/chromium-flags.conf"
    "$HOME/.config/brave-flags.conf|brave/brave-flags.conf"
    "$HOME/.config/fish/config.fish|fish/config.fish"
    "$HOME/.config/fish/fish_plugins|fish/fish_plugins"
    "$HOME/.config/fish/functions/tm.fish|fish/functions/tm.fish"
    "$HOME/.claude/CLAUDE.md|claude/CLAUDE.md"
    "$HOME/.claude/statusline-command.sh|claude/statusline-command.sh"
    "$HOME/.config/noctalia|noctalia"
    "$HOME/.local/bin/claude-usage-noctalia|local-bin/claude-usage-noctalia"
    "$HOME/.local/bin/battery-watts|local-bin/battery-watts"
    "$HOME/.local/bin/battery-time|local-bin/battery-time"
    "$HOME/.local/bin/toggl-noctalia|local-bin/toggl-noctalia"
    "$HOME/.local/bin/notification-activate|local-bin/notification-activate"
    "$HOME/.local/bin/focus-or-spawn|local-bin/focus-or-spawn"
    "$HOME/.XCompose|XCompose"
    "$HOME/.tmux.conf|tmux/tmux.conf"
    "$HOME/.tmux|tmux/tmux"
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [snapshot|restore] [options]

Modes:
  snapshot   (default) copy \$HOME → $DOTFILES/   — for committing changes.
  restore    copy $DOTFILES/ → \$HOME            — e.g. on a fresh machine.

Options:
  --only LIST    comma-separated group names (e.g. "niri,hypr"); skips picker.
  --all          select every group; skips picker.
  -y, --yes      auto-accept per-mapping prompts within selected groups.
  -n, --dry-run  preview only; never writes, never prompts.
  -h, --help

Without --only / --all an interactive group picker is shown first
(niri, hypr, tmux, …), then each mapping in the selected groups with
detected changes is confirmed individually (y/n/a/q). Directory copies
use rsync --delete: the destination becomes an exact mirror of the
source, including deletions.

After an interactive restore, a few host-specific questions are asked
(suspend-on-idle, 4K display) and applied to the relevant configs.
Skipped under --yes / --dry-run.
EOF
}

MODE="snapshot"
DRY_RUN=0
ASSUME_YES=0
SELECT_ALL=0
ONLY=""

while (( $# )); do
    case "$1" in
        snapshot|restore) MODE="$1" ;;
        -n|--dry-run) DRY_RUN=1 ;;
        -y|--yes) ASSUME_YES=1 ;;
        --all) SELECT_ALL=1 ;;
        --only) ONLY="$2"; shift ;;
        --only=*) ONLY="${1#*=}" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

command -v rsync >/dev/null || { echo "rsync is required" >&2; exit 1; }

# Per-mapping prompt default: snapshot writes to repo (low risk → Y),
# restore writes into $HOME with --delete (high risk → N).
if [[ "$MODE" == "restore" ]]; then
    DEFAULT_ANS="n"; PROMPT_HINT="[y/N/a/q]"
else
    DEFAULT_ANS="y"; PROMPT_HINT="[Y/n/a/q]"
fi

TTY_FD=""
open_tty() {
    [[ -n "$TTY_FD" ]] && return
    if [[ -t 0 ]]; then
        TTY_FD=0
    elif { exec 3</dev/tty; } 2>/dev/null; then
        TTY_FD=3
    else
        echo "no TTY available; pass --all --yes for non-interactive runs, or --dry-run to preview" >&2
        exit 1
    fi
}

# ---- helpers ---------------------------------------------------------------

group_of() {
    local dst="$1"
    [[ "$dst" == */* ]] && echo "${dst%%/*}" || echo "$dst"
}

summarize_rsync() {
    awk '
        /^\*deleting/ { sub(/^\*deleting +/, ""); print "  deleted:  " $0; next }
        /^[<>]f\+\+/  { print "  new:      " $2; next }
        /^[<>]f/      { print "  modified: " $2; next }
        /^[<>]L/      { print "  symlink:  " $2; next }
    '
}

# rsync's --dry-run with a missing destination parent errors with code 3
# instead of treating files as "new" — and rsync 3.4.1's --mkpath doesn't
# rescue dry-run. So pre-create the destination's containing dir ourselves.
ensure_dest_parent() {
    local to="$1" parent
    if [[ "$to" == */ ]]; then parent="${to%/}"; else parent="$(dirname "$to")"; fi
    [[ -d "$parent" ]] || mkdir -p "$parent"
}

# Sets globals STATUS ("missing"|"unchanged"|"changes") and CHANGES
# (friendly summary lines, empty unless STATUS=changes).
probe_mapping() {
    local from="$1" to="$2"
    STATUS=""; CHANGES=""
    if [[ ! -e "$from" ]]; then STATUS="missing"; return; fi

    local args=(-a) src="$from" dst="$to"
    if [[ -d "$from" ]]; then args+=(--delete); src="$from/"; dst="$to/"; fi

    ensure_dest_parent "$dst"

    CHANGES=$(rsync "${args[@]}" --dry-run --itemize-changes "$src" "$dst" 2>/dev/null | summarize_rsync)
    if [[ -z "$CHANGES" ]]; then STATUS="unchanged"; return; fi
    STATUS="changes"
}

apply_mapping() {
    local from="$1" to="$2"
    local args=(-a --mkpath) src="$from" dst="$to"
    if [[ -d "$from" ]]; then args+=(--delete); src="$from/"; dst="$to/"; fi
    ensure_dest_parent "$dst"
    rsync "${args[@]}" "$src" "$dst"
}

# Comment out the listener block that runs `systemctl suspend` in
# hypridle.conf; idempotent.
disable_hypridle_suspend() {
    local f="$HOME/.config/hypr/hypridle.conf"
    [[ -f "$f" ]] || return 0
    python3 - "$f" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
src = p.read_text()
def comment(m):
    return ''.join(
        ('# ' + ln if ln.strip() and not ln.lstrip().startswith('#') else ln) + '\n'
        for ln in m.group(0).rstrip('\n').splitlines()
    )
new = re.sub(
    r'^[ \t]*listener[ \t]*\{[^}]*systemctl[ \t]+suspend[^}]*\}[ \t]*\n?',
    comment, src, count=1, flags=re.MULTILINE,
)
if new != src:
    p.write_text(new)
PY
}

# Set noctalia idle.suspendTimeout to 0 (disables only the suspend
# action; lock + screen-off remain). Idempotent.
disable_noctalia_suspend() {
    local f="$HOME/.config/noctalia/settings.json"
    [[ -f "$f" ]] || return 0
    python3 - "$f" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1])
data = json.loads(p.read_text())
idle = data.get('idle')
if isinstance(idle, dict) and idle.get('suspendTimeout') != 0:
    idle['suspendTimeout'] = 0
    p.write_text(json.dumps(data, indent=2) + '\n')
PY
}

# Replace niri preset-column-widths with a 7-step set tuned for 4K
# (1/6, 1/4, 1/3, 1/2, 2/3, 3/4, 5/6). Idempotent.
apply_niri_4k_presets() {
    local f="$HOME/.config/niri/config.kdl"
    [[ -f "$f" ]] || return 0
    python3 - "$f" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
src = p.read_text()
new_block = (
    'preset-column-widths {\n'
    '        proportion 0.16667\n'
    '        proportion 0.25\n'
    '        proportion 0.33333\n'
    '        proportion 0.5\n'
    '        proportion 0.66667\n'
    '        proportion 0.75\n'
    '        proportion 0.83333\n'
    '    }'
)
new = re.sub(r'preset-column-widths[ \t]*\{[^}]*\}', new_block, src, count=1)
if new != src:
    p.write_text(new)
PY
}

# Skipped for snapshot, dry-run, and non-interactive runs.
post_restore_tweaks() {
    [[ "$MODE" == "restore" ]] || return 0
    (( DRY_RUN || ASSUME_YES )) && return 0
    open_tty
    echo
    echo "Post-restore tweaks (press Enter to accept default):"

    if [[ -n "${SELECTED[hypr]:-}" || -n "${SELECTED[noctalia]:-}" ]]; then
        if [[ "$(ask_yn "  Suspend on idle after 30 min (hypridle + noctalia)?" y)" == "no" ]]; then
            disable_hypridle_suspend
            disable_noctalia_suspend
            echo "    -> suspend-on-idle disabled (lock & screen-off kept)"
        fi
    fi

    if [[ -n "${SELECTED[niri]:-}" ]]; then
        if [[ "$(ask_yn "  4K screen? (use 7-step Mod+R cycle incl. 1/6, 1/4)" n)" == "yes" ]]; then
            apply_niri_4k_presets
            echo "    -> niri preset-column-widths set to 7 steps"
        fi
    fi
}

# Reads one line into $REPLY from $TTY_FD; returns 1 on EOF.
prompt_line() {
    printf '%s' "$1" >&2
    IFS= read -r <&"$TTY_FD" || { printf '\n' >&2; return 1; }
}

# Echoes one of: yes, no, all, quit
prompt_apply() {
    while true; do
        prompt_line "apply? $PROMPT_HINT " || { echo quit; return; }
        case "${REPLY:-$DEFAULT_ANS}" in
            [Yy]|[Yy][Ee][Ss]) echo yes; return ;;
            [Nn]|[Nn][Oo])     echo no; return ;;
            [Aa]|[Aa][Ll][Ll]) echo all; return ;;
            [Qq]|[Qq][Uu][Ii][Tt]) echo quit; return ;;
        esac
    done
}

# Echoes "yes" or "no". $1 = question, $2 = default ("y" or "n").
ask_yn() {
    local q="$1" def="${2:-n}" hint
    [[ "$def" == "y" ]] && hint="[Y/n]" || hint="[y/n]"
    while true; do
        prompt_line "$q $hint " || { [[ "$def" == y ]] && echo yes || echo no; return; }
        case "${REPLY:-$def}" in
            [Yy]|[Yy][Ee][Ss]) echo yes; return ;;
            [Nn]|[Nn][Oo])     echo no;  return ;;
        esac
    done
}

# ---- pre-scan all mappings -------------------------------------------------

declare -a M_FROM=() M_TO=() M_DST=() M_GROUP=() M_STATUS=() M_CHANGES=()

for entry in "${MAPPINGS[@]}"; do
    src_home="${entry%%|*}"
    dst_rel="${entry##*|}"
    dst_repo="$DOTFILES/$dst_rel"

    if [[ "$MODE" == "snapshot" ]]; then
        from="$src_home"; to="$dst_repo"
    else
        from="$dst_repo"; to="$src_home"
    fi

    probe_mapping "$from" "$to"
    M_FROM+=("$from"); M_TO+=("$to"); M_DST+=("$dst_rel")
    M_GROUP+=("$(group_of "$dst_rel")")
    M_STATUS+=("$STATUS"); M_CHANGES+=("$CHANGES")
done

# Ordered unique group names (sorted) + per-group counts. Don't name this
# GROUPS — bash uses that for the user's GID array.
declare -a GROUP_NAMES=()
declare -A SEEN=() G_CHANGED=() G_MISSING=() G_UNCHANGED=()
for i in "${!M_GROUP[@]}"; do
    g="${M_GROUP[i]}"
    if [[ -z "${SEEN[$g]:-}" ]]; then
        SEEN[$g]=1
        GROUP_NAMES+=("$g")
    fi
    case "${M_STATUS[i]}" in
        changes)   G_CHANGED[$g]=$((  ${G_CHANGED[$g]:-0}   + 1 )) ;;
        missing)   G_MISSING[$g]=$((  ${G_MISSING[$g]:-0}   + 1 )) ;;
        unchanged) G_UNCHANGED[$g]=$(( ${G_UNCHANGED[$g]:-0} + 1 )) ;;
    esac
done
mapfile -t GROUP_NAMES < <(printf '%s\n' "${GROUP_NAMES[@]}" | sort)

# ---- group selection -------------------------------------------------------

declare -A SELECTED=()

select_groups_from_only() {
    local g IFS=','
    for g in $ONLY; do
        g="${g// /}"
        [[ -z "$g" ]] && continue
        if [[ -z "${SEEN[$g]:-}" ]]; then
            unset IFS
            echo "unknown group: $g" >&2
            echo "available: ${GROUP_NAMES[*]}" >&2
            exit 1
        fi
        SELECTED[$g]=1
    done
}

select_all_groups() {
    local g
    for g in "${GROUP_NAMES[@]}"; do SELECTED[$g]=1; done
}

render_menu() {
    local width=0 g i
    for g in "${GROUP_NAMES[@]}"; do (( ${#g} > width )) && width=${#g}; done
    printf '\nGroups (%s, %s → %s):\n\n' "$MODE" \
        "$([[ $MODE == snapshot ]] && echo host || echo repo)" \
        "$([[ $MODE == snapshot ]] && echo repo || echo host)"
    for i in "${!GROUP_NAMES[@]}"; do
        g="${GROUP_NAMES[i]}"
        local desc=""
        (( ${G_CHANGED[$g]:-0}   > 0 )) && desc+="${G_CHANGED[$g]} changed, "
        (( ${G_MISSING[$g]:-0}   > 0 )) && desc+="${G_MISSING[$g]} missing, "
        (( ${G_UNCHANGED[$g]:-0} > 0 )) && desc+="${G_UNCHANGED[$g]} unchanged, "
        printf "  [%2d] %-${width}s  %s\n" $((i+1)) "$g" "${desc%, }"
    done
    echo
    echo 'Pick: numbers ("1,3" or "1-5"), "a" all, "c" only with changes, "q" quit'
}

parse_selection() {
    local sel="${1// /}" tok a b n
    [[ -z "$sel" ]] && return 1
    local IFS=','
    for tok in $sel; do
        if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            a="${BASH_REMATCH[1]}"; b="${BASH_REMATCH[2]}"
            (( a < 1 || b > ${#GROUP_NAMES[@]} || a > b )) && return 1
            for ((n=a; n<=b; n++)); do SELECTED["${GROUP_NAMES[n-1]}"]=1; done
        elif [[ "$tok" =~ ^[0-9]+$ ]]; then
            (( tok < 1 || tok > ${#GROUP_NAMES[@]} )) && return 1
            SELECTED["${GROUP_NAMES[tok-1]}"]=1
        else
            return 1
        fi
    done
}

if [[ -n "$ONLY" ]]; then
    select_groups_from_only
elif (( SELECT_ALL || ASSUME_YES || DRY_RUN )); then
    select_all_groups
else
    open_tty
    render_menu
    while true; do
        prompt_line '> ' || { echo "exiting"; exit 0; }
        case "${REPLY// /}" in
            ""|q|Q|quit) echo "nothing selected; exiting"; exit 0 ;;
            a|A|all) select_all_groups; break ;;
            c|C|changed)
                for g in "${GROUP_NAMES[@]}"; do
                    (( ${G_CHANGED[$g]:-0} > 0 )) && SELECTED[$g]=1
                done
                if (( ${#SELECTED[@]} == 0 )); then
                    echo "no groups have changes."
                    continue
                fi
                break
                ;;
            *)
                if parse_selection "$REPLY"; then break; fi
                echo "invalid selection."
                SELECTED=()
                ;;
        esac
    done
fi

(( ${#SELECTED[@]} == 0 )) && { echo "nothing selected; exiting"; exit 0; }

# ---- per-mapping interactive apply -----------------------------------------

(( ! ASSUME_YES && ! DRY_RUN )) && open_tty

applied=0; declined=0; unchanged=0; missing=0; would_apply=0
summary_suffix=""

for i in "${!M_FROM[@]}"; do
    [[ -z "${SELECTED[${M_GROUP[i]}]:-}" ]] && continue

    case "${M_STATUS[i]}" in
        missing)   echo "missing: ${M_FROM[i]}"; ((++missing)); continue ;;
        unchanged) ((++unchanged)); continue ;;
    esac

    printf '\n=== %s\n  %s -> %s\n' "${M_DST[i]}" "${M_FROM[i]}" "${M_TO[i]}"
    printf '%s\n' "${M_CHANGES[i]}"

    if (( DRY_RUN )); then ((++would_apply)); continue; fi

    if (( ! ASSUME_YES )); then
        case "$(prompt_apply)" in
            yes) : ;;
            no)  ((++declined)); continue ;;
            all) ASSUME_YES=1 ;;
            quit) summary_suffix=" (quit early)"; break ;;
        esac
    fi

    apply_mapping "${M_FROM[i]}" "${M_TO[i]}"
    ((++applied))
done

post_restore_tweaks

# ---- summary ---------------------------------------------------------------

echo
if (( DRY_RUN )); then
    printf '%s dry-run: %d would apply, %d unchanged, %d missing\n' \
        "$MODE" "$would_apply" "$unchanged" "$missing"
else
    printf '%s: %d applied, %d declined, %d unchanged, %d missing%s\n' \
        "$MODE" "$applied" "$declined" "$unchanged" "$missing" "$summary_suffix"
fi
if [[ "$MODE" == "snapshot" ]] && (( ! DRY_RUN && applied > 0 )); then
    echo "Next: review with 'git status' / 'git diff dotfiles/' and commit."
fi
