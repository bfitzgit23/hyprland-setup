#!/usr/bin/env bash
# Screenshots on Wayland: grim captures, slurp selects, swappy annotates.
#   screenshot.sh <region|output|full> <annotate|clip>
# Bound in hyprland.lua to PRINT / SHIFT+PRINT / SUPER+PRINT / SUPER+SHIFT+PRINT.
set -u

mode=${1:-region}
action=${2:-clip}
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

command -v grim >/dev/null || { echo "grim is not installed" >&2; exit 1; }

case "$mode" in
    region)
        command -v slurp >/dev/null || { echo "slurp is not installed" >&2; exit 1; }
        geom=$(slurp) || exit 0
        grim -g "$geom" "$file" || exit 1
        ;;
    output)
        out=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
        grim -o "$out" "$file" || exit 1
        ;;
    full)
        grim "$file" || exit 1
        ;;
    *)
        echo "usage: $0 <region|output|full> <annotate|clip>" >&2
        exit 2
        ;;
esac

case "$action" in
    annotate)
        if command -v swappy >/dev/null; then
            swappy -f "$file" -o "$file"
            command -v wl-copy >/dev/null && wl-copy < "$file"
        else
            notify-send "Screenshot" "swappy missing, saved $file"
        fi
        ;;
    clip)
        if command -v wl-copy >/dev/null; then
            wl-copy < "$file"
            notify-send "Screenshot" "Copied to clipboard"
        else
            notify-send "Screenshot" "wl-clipboard missing, saved $file"
        fi
        ;;
esac
