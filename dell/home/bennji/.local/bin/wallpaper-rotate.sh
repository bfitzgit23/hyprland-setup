#!/usr/bin/env bash
# Shuffles through /usr/share/backgrounds every 15 minutes, unless the picker
# (wallpaper-picker.sh) has pinned an image: a pin wins until it is removed, and
# it is re-read between ticks so a pick applies without restarting this loop.
BG_DIR="/usr/share/backgrounds"
INTERVAL=900
# The panel is 1920x1080 and swww fills the screen by magnifying the image, so a
# 4:3 file from the gentoo10 tree (it ships 800x600, 1024x768, 1366x768, ...)
# lands on screen hugely upscaled and blurry. Shuffle only wallpapers that are
# at least as big as the screen; anything larger is centre-cropped to fit.
SCREEN_W=1920
SCREEN_H=1080
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
PIN="$STATE/wallpaper-pin"
CURRENT="$STATE/wallpaper-current"
mkdir -p "$STATE"

swww-daemon &
sleep 1

current() { cat "$CURRENT" 2>/dev/null; }

big_enough() {
    python3 - "$1" "$SCREEN_W" "$SCREEN_H" <<'PY'
import sys
try:
    from PIL import Image
    with Image.open(sys.argv[1]) as im:
        w, h = im.size
except Exception:
    sys.exit(1)
sys.exit(0 if w >= int(sys.argv[2]) and h >= int(sys.argv[3]) else 1)
PY
}

apply() {
    [ "$1" = "$(current)" ] && return
    swww img "$1" --transition-type fade --transition-duration 2 >/dev/null 2>&1
    printf '%s\n' "$1" > "$CURRENT"
}

random_image() {
    find "$BG_DIR" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        2>/dev/null | shuf | while IFS= read -r f; do
            big_enough "$f" && { printf '%s\n' "$f"; break; }
        done
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
