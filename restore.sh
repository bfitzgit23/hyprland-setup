#!/usr/bin/env bash
# Reinstall a Hyprland desktop from a snapshot in this folder.
#
#   ./restore.sh dell                 # from ./dell            (pulled from the Dell box)
#   ./restore.sh a16                  # from ./a16-profile     (GIGABYTE A16 profile)
#   ./restore.sh dell --dry-run       # print what would happen, change nothing
#   ./restore.sh dell --user bennji   # force the target desktop user
#   ./restore.sh dell --packages      # also run emerge for packages.list / world
#
# Run as root on the target machine (dry-run works unprivileged). Existing files
# are kept as <name>.bak-<timestamp>; nothing is deleted.
set -euo pipefail

PROFILE=""
TARGET_USER=""
DRY=0
DO_PACKAGES=0
STAMP=$(date +%Y%m%d%H%M%S)

die() { printf 'restore: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        dell|a16)     PROFILE="$1" ;;
        --user)       TARGET_USER="${2:?--user needs a name}"; shift ;;
        --user=*)     TARGET_USER="${1#*=}" ;;
        --dry-run|-n) DRY=1 ;;
        --packages)   DO_PACKAGES=1 ;;
        -h|--help)    usage 0 ;;
        *)            die "unknown argument: $1 (try --help)" ;;
    esac
    shift
done

[ -n "$PROFILE" ] || usage 1
HERE=$(cd "$(dirname "$0")" && pwd)
case "$PROFILE" in
    dell) SRC="$HERE/dell" ;;
    a16)  SRC="$HERE/a16-profile" ;;
esac
[ -d "$SRC" ] || die "no snapshot at $SRC (run ./pull.sh first, or check the folder)"

if [ "$DRY" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
    die "run as root, or add --dry-run"
fi

run() {
    if [ "$DRY" -eq 1 ]; then printf '  would run: %s\n' "$*"; else "$@"; fi
}

# Keep the old copy of anything we overwrite, so a bad restore is reversible.
put() {   # put <source> <destination>
    local src="$1" dst="$2"
    if [ -e "$dst" ]; then
        run cp -a "$dst" "$dst.bak-$STAMP"
    fi
    run install -D -m "$(stat -c %a "$src")" "$src" "$dst"
}

# ---------------------------------------------------------------- target user
if [ -z "$TARGET_USER" ]; then
    TARGET_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1; exit}')
fi
[ -n "$TARGET_USER" ] || die "could not find a desktop user; pass --user NAME"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_GROUP=$(id -gn "$TARGET_USER")
[ -n "$TARGET_HOME" ] || die "no home directory for $TARGET_USER"

printf 'profile : %s\nsource  : %s\nuser    : %s (%s)\nhome    : %s\nmode    : %s\n\n' \
    "$PROFILE" "$SRC" "$TARGET_USER" "$TARGET_GROUP" "$TARGET_HOME" \
    "$([ "$DRY" -eq 1 ] && echo 'dry run' || echo 'install')"

# ------------------------------------------------------------------- home dir
# dell/ is a mirror of the machine's filesystem; a16-profile/ is a hand-written
# layout. Map both onto the target user's home.
if [ -d "$SRC/home" ]; then
    SNAP_USER=$(find "$SRC/home" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [ -n "$SNAP_USER" ]; then
        echo "[home] $SNAP_USER -> $TARGET_HOME"
        while IFS= read -r -d '' f; do
            rel=${f#"$SNAP_USER"/}
            put "$f" "$TARGET_HOME/$rel"
        done < <(find "$SNAP_USER" -type f -print0)
    fi
fi

for dir in hypr quickshell local-bin icons; do
    [ -d "$SRC/$dir" ] || continue
    case "$dir" in
        hypr)       dest="$TARGET_HOME/.config/hypr" ;;
        quickshell) dest="$TARGET_HOME/.config/quickshell" ;;
        local-bin)  dest="$TARGET_HOME/.local/bin" ;;
        icons)      dest="$TARGET_HOME/.local/share/icons" ;;
    esac
    echo "[home] $dir -> $dest"
    while IFS= read -r -d '' f; do
        put "$f" "$dest/${f##*/}"
    done < <(find "$SRC/$dir" -type f -print0)
done

# ------------------------------------------------------------------ root tree
for top in etc usr var; do
    [ -d "$SRC/$top" ] || continue
    echo "[root] $top/"
    while IFS= read -r -d '' f; do
        put "$f" "/${f#"$SRC"/}"
    done < <(find "$SRC/$top" -type f -print0)
done

# a16 ships portage snippets as single files rather than a tree
if [ -d "$SRC/portage" ]; then
    echo "[root] portage snippets"
    for f in "$SRC"/portage/package.use.*; do
        [ -f "$f" ] || continue
        put "$f" "/etc/portage/package.use/${f##*/package.use.}"
    done
fi
# ------------------------------------------------------------------- packages
# A snapshot ships the live world file; a hand-written profile ships
# packages.list. Either is used with --packages.
PKG_LIST=""
if [ -f "$SRC/packages.list" ]; then
    PKG_LIST="$SRC/packages.list"
elif [ -f "$SRC/var/lib/portage/world" ]; then
    PKG_LIST="$SRC/var/lib/portage/world"
fi
if [ -n "$PKG_LIST" ]; then
    N=$(grep -cve '^\s*$' "$PKG_LIST" || true)
    echo "[pkgs] $N atoms in ${PKG_LIST#"$HERE"/}"
    if [ "$DO_PACKAGES" -eq 1 ]; then
        mapfile -t ATOMS < <(grep -ve '^\s*$' "$PKG_LIST")
        run emerge --ask --noreplace "${ATOMS[@]}"
    else
        echo "  (skipped; re-run with --packages to emerge them)"
    fi
fi

# ------------------------------------------------------------------- services
if [ -f "$SRC/services.list" ]; then
    echo "[svc ] $(grep -cve '^\s*$' "$SRC/services.list") OpenRC services"
    while read -r svc; do
        [ -n "$svc" ] || continue
        run rc-update add "$svc" default
    done < "$SRC/services.list"
fi

# ------------------------------------------------------------------ ownership
if [ -d "$TARGET_HOME" ]; then
    echo "[own ] $TARGET_USER:$TARGET_GROUP -> $TARGET_HOME"
    run chown -R "$TARGET_USER:$TARGET_GROUP" \
        "$TARGET_HOME/.config/hypr" "$TARGET_HOME/.config/quickshell" \
        "$TARGET_HOME/.local/bin" "$TARGET_HOME/.local/share/icons" 2>/dev/null || true
    run chmod +x "$TARGET_HOME"/.local/bin/*.sh "$TARGET_HOME"/.local/bin/keybinds.py 2>/dev/null || true
fi

if [ "$DRY" -eq 0 ]; then
    command -v udevadm >/dev/null && udevadm control --reload-rules 2>/dev/null || true
fi

cat <<EOF

Done. Still manual:
  * reboot once, so modprobe.d changes (bcma/b43 stubs, wl nompc=1) take effect
  * fingerprint: fprintd-enroll in an active session, then fprint-enable.sh
  * rustdesk: rc-service rustdesk start  (service env lives in /etc/conf.d/rustdesk)
  * log out and back in so LightDM picks up the session wrapper
EOF
