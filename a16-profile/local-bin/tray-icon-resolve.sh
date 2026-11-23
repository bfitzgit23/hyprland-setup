#!/usr/bin/env bash
# Resolve a StatusNotifier icon for the bar. Prints one line:
#     mono <path>     greyscale glyph -> bar tints it
#     colour <path>   colour artwork  -> bar draws it as-is
#     colour          nothing resolvable -> bar falls back to modelData.icon
#
# Arguments: <icon> <id>
#   icon  the item's icon name, or an image:// URI for app-supplied pixmaps
#   id    the SNI id, used for per-app overrides
#
# This is a portable port of the resolver used on the reference desktop; that
# one also maps Discord's blank pixmap to a Tela artwork file that only exists
# there. Set images per app in the case block below if you need the same.
set -u

icon=${1:-}
id=${2:-}

# Discord publishes an empty 1x1 pixmap as its SNI icon, which renders as a
# blank slot. Fall back to its application icon from the theme.
case "$id" in
    discord_status_icon_*|discord*)
        for candidate in discord discord-canary; do
            found=$(find -L "$HOME/.local/share/icons" /usr/share/icons \
                    -name "${candidate}.png" -print -quit 2>/dev/null)
            [ -n "$found" ] && { echo "colour $found"; exit 0; }
        done
        ;;
esac

# Application-supplied pixmaps cannot be resolved to a file: let Qt draw them.
case "$icon" in
    image://*) echo "colour"; exit 0 ;;
    "")        echo "colour"; exit 0 ;;
esac

theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
theme=${theme:-Adwaita}

path=$(find -L "$HOME/.local/share/icons/$theme" \
              "/usr/share/icons/$theme" \
              /usr/share/icons/hicolor \
              -name "${icon}.png" -print -quit 2>/dev/null)
[ -z "$path" ] && path=$(find -L "$HOME/.local/share/icons/$theme" \
              "/usr/share/icons/$theme" /usr/share/icons/hicolor \
              -name "${icon}.svg" -print -quit 2>/dev/null)

if [ -z "$path" ]; then
    echo "colour"
elif [ "${icon%-symbolic}" != "$icon" ]; then
    echo "mono $path"
else
    echo "colour $path"
fi
