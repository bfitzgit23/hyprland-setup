#!/usr/bin/env bash
# Wallpaper picker. Lists the same images wallpaper-rotate.sh shuffles through,
# plus anything in ~/Pictures, in a rofi menu with thumbnails. Picking one
# applies it immediately and pins it (STATE/wallpaper-pin) so the rotation loop
# stops replacing it; the first entry unpins and hands control back.
set -u

STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
PIN="$STATE/wallpaper-pin"
CURRENT="$STATE/wallpaper-current"
UNPIN_ICON="/usr/share/icons/Adwaita/symbolic/actions/view-refresh-symbolic.svg"
mkdir -p "$STATE" /tmp

mapfile -t FILES < <(
    find /usr/share/backgrounds "$HOME/Pictures" -maxdepth 3 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        2>/dev/null | sort
)

if [ "${#FILES[@]}" -eq 0 ]; then
    notify-send "Wallpaper" "No images in /usr/share/backgrounds or ~/Pictures"
    exit 1
fi

pinned=""
[ -s "$PIN" ] && pinned=$(head -n1 "$PIN")

rows() {
    local label="↻  Resume auto-rotation"
    [ -n "$pinned" ] && label="↻  Resume auto-rotation (pinned: $(basename "$pinned"))"
    printf '%s\0icon\x1f%s\n' "$label" "$UNPIN_ICON"
    for f in "${FILES[@]}"; do
        local name
        name=$(basename "$f")
        [ "$f" = "$pinned" ] && name="● $name"
        printf '%s\0icon\x1f%s\n' "$name" "$f"
    done
}

# -format i returns the row index, which avoids matching on basenames that can
# repeat between /usr/share/backgrounds and ~/Pictures.
pick=$(rows | rofi -dmenu -i -show-icons -p "Wallpaper" -format i -no-custom 2>/dev/null)
[ -z "${pick:-}" ] && exit 0

apply() {
    swww img "$1" --transition-type wipe --transition-duration 1 >/dev/null 2>&1
    printf '%s\n' "$1" > "$CURRENT"
    notify-send "Wallpaper" "$(basename "$1")"
}

if [ "$pick" -eq 0 ]; then
    rm -f "$PIN"
    # Show something different straight away, otherwise the pinned image stays
    # on screen until the rotation loop's next 15 minute tick.
    next=$(find /usr/share/backgrounds -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        2>/dev/null | shuf -n1)
    [ -n "$next" ] && apply "$next"
    exit 0
fi

target="${FILES[$((pick - 1))]}"
[ -n "$target" ] || exit 0
printf '%s\n' "$target" > "$PIN"
apply "$target"
