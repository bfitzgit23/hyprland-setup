#!/bin/sh
# Screenshot capture for Hyprland. flameshot cannot read a Wayland surface
# (it has no capture on Hyprland), so grim does the capture and swappy does the
# annotation, clipboard and saving.
#   usage: screenshot.sh [region|output|full] [annotate|clip|path]
mode=${1:-region}
action=${2:-annotate}
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir" || exit 1
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$mode" in
    region)
        geom=$(slurp) || exit 0
        grim -g "$geom" "$file" || exit 1
        ;;
    output)
        mon=$(hyprctl monitors -j | sed -n 's/.*"name": "\([^"]*\)".*/\1/p' | head -1)
        grim -o "${mon:-}" "$file" || exit 1
        ;;
    *)
        grim "$file" || exit 1
        ;;
esac

case "$action" in
    clip)
        wl-copy --type image/png < "$file"
        command -v notify-send >/dev/null && notify-send -a Screenshot -t 2500 "Screenshot copied" "$(basename "$file")"
        ;;
    annotate)
        if command -v swappy >/dev/null 2>&1; then
            swappy -f "$file" -o "$file"
        else
            command -v notify-send >/dev/null && notify-send -a Screenshot "Screenshot saved" "$file"
        fi
        ;;
    *)
        command -v notify-send >/dev/null && notify-send -a Screenshot "Screenshot saved" "$file"
        ;;
esac
