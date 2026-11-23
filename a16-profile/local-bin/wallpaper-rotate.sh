#!/usr/bin/env bash
# Shuffles through /usr/share/backgrounds every 15 minutes, unless the picker
# (wallpaper-picker.sh) has pinned an image: a pin wins until it is removed, and
# it is re-read between ticks so a pick applies without restarting this loop.
BG_DIR="/usr/share/backgrounds"
INTERVAL=900
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
PIN="$STATE/wallpaper-pin"
CURRENT="$STATE/wallpaper-current"
mkdir -p "$STATE"

swww-daemon &
sleep 1

current() { cat "$CURRENT" 2>/dev/null; }

apply() {
    [ "$1" = "$(current)" ] && return
    swww img "$1" --transition-type fade --transition-duration 2 >/dev/null 2>&1
    printf '%s\n' "$1" > "$CURRENT"
}

random_image() {
    find "$BG_DIR" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        2>/dev/null | shuf -n 1
}

while true; do
    pinned=""
    [ -s "$PIN" ] && pinned=$(head -n1 "$PIN")

    if [ -n "$pinned" ] && [ -f "$pinned" ]; then
        apply "$pinned"
        sleep 3
        continue
    fi

    img=$(random_image)
    [ -n "$img" ] && apply "$img"

    # Wait out the interval, but notice a new pin within a few seconds so the
    # picker's choice is not overwritten by a pending tick.
    waited=0
    while [ "$waited" -lt "$INTERVAL" ]; do
        sleep 5
        waited=$((waited + 5))
        if [ -s "$PIN" ]; then
            break
        fi
    done
done
