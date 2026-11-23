#!/usr/bin/env bash
# cmus does not expose MPRIS, so the bar (which reads MPRIS for VLC/Spotify/
# Chromium) falls back to this when no MPRIS player is active.
# Prints "status|artist|title", or nothing at all when cmus is not running.
set -u

pidof cmus >/dev/null 2>&1 || exit 0

out=$(cmus-remote -Q 2>/dev/null) || exit 0

status=$(printf '%s\n' "$out" | sed -n 's/^status //p' | head -n1)
artist=$(printf '%s\n' "$out" | sed -n 's/^tag artist //p' | head -n1)
title=$(printf '%s\n' "$out"  | sed -n 's/^tag title //p'  | head -n1)
file=$(printf '%s\n' "$out"   | sed -n 's/^file //p'       | head -n1)

[ -z "$title" ] && title=$(basename "${file:-}" 2>/dev/null)
[ -z "$status" ] && status=stopped

printf '%s|%s|%s\n' "$status" "$artist" "$title"
