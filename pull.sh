#!/usr/bin/env bash
# Snapshot a running Hyprland box into this folder, ready for ./restore.sh.
#
#   ./pull.sh                       # Dell default: 10.0.0.37, root, folder dell/
#   ./pull.sh 10.0.0.50 bennji      # another box (the A16 later), same layout
#   OUT=a16-live ./pull.sh 10.0.0.50 bennji
#
# Password auth is used because these boxes have no SSH key installed; pass it
# as the third argument or let the script prompt. Afterwards ./restore.sh dell
# (or the OUT folder, once it has a profile name) installs it on a fresh machine.
set -euo pipefail
cd "$(dirname "$0")"

HOST="${1:-10.0.0.37}"
USER_NAME="${2:-root}"
OUT_DIR="${OUT:-dell}"

if [ "$#" -ge 3 ]; then
    export DELL_PW="$3"
elif [ -z "${DELL_PW:-}" ]; then
    printf 'password for %s@%s: ' "$USER_NAME" "$HOST" >&2
    stty -echo 2>/dev/null || true
    read -r DELL_PW
    stty echo 2>/dev/null || true
    printf '\n' >&2
    export DELL_PW
fi

PY="${PYTHON:-python}"
command -v "$PY" >/dev/null || PY=python3
OUT="$OUT_DIR" exec "$PY" pull_dell.py "$HOST" "$USER_NAME" "${DELL_PW:-}"
