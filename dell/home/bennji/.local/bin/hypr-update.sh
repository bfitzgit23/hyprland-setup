#!/bin/sh
# hypr-update.sh - update the Hyprland stack and this desktop's dotfiles.
#
#   hypr-update.sh                 Hyprland packages + dotfiles, then reload
#   hypr-update.sh --check         report what is behind, change nothing
#   hypr-update.sh --dots-only     dotfiles only (no root needed)
#   hypr-update.sh --system-only   Hyprland packages only
#   hypr-update.sh --quiet         log to ~/.local/state/hypr-update/last.log
#
# Dotfiles come from the hyprland-setup repo (override with HYPR_DOTS_REPO):
# cloned or fast-forwarded into ~/.local/share/hyprland-setup, then the profile
# matching this host is copied into ~/.config and ~/.local/bin. Files that
# differ are kept as <name>.bak-<timestamp>. Emerge runs under sudo, so the
# system part needs an interactive prompt - run it from a terminal (the bar
# menu item opens kitty for exactly that reason).
set -eu

REPO="${HYPR_DOTS_REPO:-https://github.com/bfitzgit23/hyprland-setup.git}"
DIR="${HYPR_DOTS_DIR:-$HOME/.local/share/hyprland-setup}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-update"
LOG="$STATE/last.log"
STAMP=$(date +%Y%m%d%H%M%S)

# The stack that makes this desktop what it is. quickshell is a live ebuild
# (9999), so it is rebuilt from upstream on every run that includes it.
ATOMS="gui-wm/hyprland gui-libs/hyprutils gui-apps/hypridle gui-apps/hyprlock
gui-libs/xdg-desktop-portal-hyprland gui-apps/quickshell"

DO_SYSTEM=1
DO_DOTS=1
CHECK=0
QUIET=0
PROFILE="${HYPR_PROFILE:-auto}"

usage() {
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --check)       CHECK=1 ;;
        --dots-only)   DO_SYSTEM=0 ;;
        --system-only) DO_DOTS=0 ;;
        --quiet)       QUIET=1 ;;
        --profile=*)   PROFILE="${1#*=}" ;;
        -h|--help)     usage 0 ;;
        *)             printf 'hypr-update: unknown argument: %s (try --help)\n' "$1" >&2; exit 1 ;;
    esac
    shift
done

if [ "$QUIET" -eq 1 ]; then
    mkdir -p "$STATE"
    exec >>"$LOG" 2>&1
    printf '\n=== %s ===\n' "$(date -Is)"
fi

say() { printf '%s\n' "$*"; }

# --------------------------------------------------------------------- profile
if [ "$PROFILE" = auto ]; then
    case "$(hostname)" in
        *[Dd]ell*|*[Pp]recision*) PROFILE=dell ;;
        *)                        PROFILE=a16 ;;
    esac
fi
say "profile : $PROFILE ($(hostname))"
say "dotfiles: $DIR"

# ---------------------------------------------------------------------- system
if [ "$DO_SYSTEM" -eq 1 ]; then
    if [ "$CHECK" -eq 1 ]; then
        say ''
        say '[system] checking for updates'
        # -p only prints; it works unprivileged, and any failure here is a
        # real portage error worth showing.
        emerge -p -u --changed-use --noreplace $ATOMS 2>&1 | grep -E '^\[' || say '  (nothing to do)'
    else
        say ''
        say '[system] emerge -u --changed-use --noreplace'
        # shellcheck disable=SC2086  # ATOMS is a deliberate word list
        sudo emerge -u --changed-use --noreplace $ATOMS
    fi
fi

# ------------------------------------------------------------------ dotfiles
if [ "$DO_DOTS" -eq 1 ]; then
    say ''
    if [ -d "$DIR/.git" ]; then
        say "[dots] fetching $(basename "$REPO")"
        if [ "$CHECK" -eq 1 ]; then
            git -C "$DIR" fetch --quiet origin || say '  (fetch failed)'
            BEHIND=$(git -C "$DIR" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
            say "  $BEHIND commit(s) behind upstream"
        else
            git -C "$DIR" pull --ff-only
        fi
    elif [ "$CHECK" -eq 1 ]; then
        say "[dots] $DIR is not a checkout yet (nothing to compare)"
    else
        say "[dots] cloning $REPO"
        mkdir -p "$(dirname "$DIR")"
        git clone "$REPO" "$DIR"
    fi

    if [ "$CHECK" -eq 0 ] && [ -d "$DIR/.git" ]; then
        [ -d "$DIR/dell" ] || [ -d "$DIR/a16-profile" ] || {
            say "hypr-update: no profiles in $DIR" >&2
            exit 1
        }
        # Copy only files that differ, keeping the previous copy alongside.
        install_tree() {   # install_tree <source dir> <destination dir>
            [ -d "$1" ] || return 0
            find "$1" -type f -print | while IFS= read -r f; do
                rel=${f#"$1"/}
                dst="$2/$rel"
                if [ -f "$dst" ] && cmp -s "$f" "$dst"; then
                    continue
                fi
                if [ -f "$dst" ]; then
                    cp -p "$dst" "$dst.bak-$STAMP"
                fi
                install -D -m "$(stat -c %a "$f")" "$f" "$dst"
                say "  updated ${dst#"$HOME"/}"
            done
        }

        case "$PROFILE" in
            dell)
                SNAP_HOME=$(find "$DIR/dell/home" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
                if [ -n "$SNAP_HOME" ]; then
                    install_tree "$SNAP_HOME/.config/hypr"       "$HOME/.config/hypr"
                    install_tree "$SNAP_HOME/.config/quickshell" "$HOME/.config/quickshell"
                    install_tree "$SNAP_HOME/.local/bin"         "$HOME/.local/bin"
                fi
                ;;
            a16)
                install_tree "$DIR/a16-profile/hypr"       "$HOME/.config/hypr"
                install_tree "$DIR/a16-profile/quickshell" "$HOME/.config/quickshell"
                install_tree "$DIR/a16-profile/local-bin"  "$HOME/.local/bin"
                ;;
            *)
                say "hypr-update: unknown profile '$PROFILE'" >&2
                exit 1
                ;;
        esac
    fi
fi

# -------------------------------------------------------------------- reload
if [ "$CHECK" -eq 1 ]; then
    say ''
    say 'check only - nothing changed'
    exit 0
fi

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
    say ''
    say '[reload] hyprctl reload + quickshell restart'
    hyprctl reload >/dev/null 2>&1 || say '  (hyprctl reload failed)'
    pkill -x quickshell >/dev/null 2>&1 || true
    sleep 0.4
    hyprctl dispatch exec quickshell >/dev/null 2>&1 || say '  (could not restart quickshell)'
else
    say ''
    say 'not inside a Hyprland session - log out and back in to pick it up'
fi
