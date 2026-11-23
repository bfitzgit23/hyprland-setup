#!/bin/sh
# Resolve a StatusNotifier icon through the user's icon theme (Tela) and render
# it at the bar's exact pixel size, so the glyph detail that survives at 20px is
# the detail rsvg produced at 20px rather than a downsample of something bigger.
# Prints "<verdict> [png]":
#   mono <png>  simple silhouette -> draw tinted
#   art  <png>  artwork with an interior glyph -> draw as-is
#   colour      application pixmap (RustDesk) -> draw the provider URL
url=${1:-}
id=${2:-}
mask=0
pixmap=0
case $url in
    # An app pixmap with a coloured mark on a plate: keep the mark, tint it.
    *[Rr]ust[Dd]esk*) name=rustdesk; mask=1 ;;
    image://icon/*) name=${url#image://icon/} ;;
    image://qspixmap/*) pixmap=1 ;;
    *) echo "colour"; exit 0 ;;
esac

# An item that publishes only a DBus pixmap and no theme name has no artwork the
# theme can look up. Discord's pixmap is blank -- measured, it draws nothing in
# the 22px slot -- so a themed glyph stands in for it. Any other pixmap-only
# item keeps its own image.
if [ "$pixmap" = 1 ]; then
    case $id in
        discord_status_icon_1) name=discord-tray ;;
        *) echo "colour"; exit 0 ;;
    esac
fi
case $name in
    ""|*/*|*\?*|*.png|*.svg) echo "colour"; exit 0 ;;
esac

# blueman's own panel art is a 16px pill whose inner glyph cannot survive at bar
# size; Tela carries the same idea as a full-size symbolic glyph, like the rest
# of the bar's indicators.
case $name in
    blueman-tray|blueman-active|blueman-panel) name=bluetooth-active-symbolic ;;
esac

theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
f=""
for dir in "${theme:-Adwaita}" Adwaita hicolor HighContrast; do
    for sub in 16@2x/panel 16/panel 22/panel 24/panel 16@2x/status 16/status scalable/apps 22/apps symbolic/status symbolic/devices symbolic/actions; do
        [ -n "$f" ] && break
        [ -f "/usr/share/icons/$dir/$sub/$name.svg" ] && f="/usr/share/icons/$dir/$sub/$name.svg"
    done
    [ -n "$f" ] && break
    f=$(find -L "/usr/share/icons/$dir" -name "$name.svg" -print -quit 2>/dev/null)
done
[ -n "$f" ] || { echo "colour"; exit 0; }

tmp=$(mktemp -d) || exit 0
trap 'rm -rf "$tmp"' EXIT

out=${XDG_RUNTIME_DIR:-/tmp}/tray-icons
mkdir -p "$out" 2>/dev/null || { out=/tmp/tray-icons; mkdir -p "$out"; }

if [ "$mask" = 1 ]; then
    rsvg-convert -w 64 -h 64 -o "$tmp/a.png" "$f" 2>/dev/null || { echo "colour"; exit 0; }
    if python3 /home/bennji/.local/bin/tray-icon-mask.py "$tmp/a.png" "$out/$name.png" 18 2>/dev/null; then
        echo "mono $out/$name.png"
    else
        echo "colour"
    fi
    exit 0
fi

rsvg-convert -w 64 -h 64 -o "$tmp/a.png" "$f" 2>/dev/null || { echo "colour"; exit 0; }

verdict=$(python3 - "$tmp/a.png" <<'PYEOF'
import struct
import sys
import zlib

data = open(sys.argv[1], 'rb').read()
pos, idat = 8, b''
w = h = depth = color = None
while pos < len(data) - 8:
    ln, typ = struct.unpack('>I4s', data[pos:pos + 8])
    body = data[pos + 8:pos + 8 + ln]
    if typ == b'IHDR':
        w, h, depth, color = struct.unpack('>IIBB', body[:10])
    elif typ == b'IDAT':
        idat += body
    pos += 12 + ln
if color not in (2, 6) or depth != 8:
    print('art')
    raise SystemExit
bpp = 4 if color == 6 else 3
stride = w * bpp
raw = zlib.decompress(idat)
prev = bytearray(stride)
alpha = []
opaque = saturated = 0
i = 0
for _ in range(h):
    ft = raw[i]
    i += 1
    line = bytearray(raw[i:i + stride])
    i += stride
    for x in range(stride):
        left = line[x - bpp] if x >= bpp else 0
        up = prev[x]
        ul = prev[x - bpp] if x >= bpp else 0
        if ft == 1:
            line[x] = (line[x] + left) & 0xFF
        elif ft == 2:
            line[x] = (line[x] + up) & 0xFF
        elif ft == 3:
            line[x] = (line[x] + (left + up) // 2) & 0xFF
        elif ft == 4:
            p = left + up - ul
            pa, pb, pc = abs(p - left), abs(p - up), abs(p - ul)
            pred = left if (pa <= pb and pa <= pc) else (up if pb <= pc else ul)
            line[x] = (line[x] + pred) & 0xFF
    prev = line
    row = []
    for x in range(0, stride, bpp):
        a = line[x + 3] if bpp == 4 else 255
        row.append(a)
        if a >= 64:
            opaque += 1
            r, g, b = line[x], line[x + 1], line[x + 2]
            if max(r, g, b) - min(r, g, b) > 40:
                saturated += 1
    alpha.append(row)

# Interior clear areas are inner glyphs; flattening them to one tint erases them.
seen = [[False] * w for _ in range(h)]
stack = []
for x in range(w):
    for y in (0, h - 1):
        if alpha[y][x] < 64 and not seen[y][x]:
            seen[y][x] = True
            stack.append((x, y))
for y in range(h):
    for x in (0, w - 1):
        if alpha[y][x] < 64 and not seen[y][x]:
            seen[y][x] = True
            stack.append((x, y))
while stack:
    x, y = stack.pop()
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < w and 0 <= ny < h and alpha[ny][nx] < 64 and not seen[ny][nx]:
            seen[ny][nx] = True
            stack.append((nx, ny))
enclosed = sum(1 for y in range(h) for x in range(w)
               if alpha[y][x] < 64 and not seen[y][x])

if not opaque or saturated / opaque >= 0.25 or enclosed / float(w * h) > 0.05:
    print('art')
else:
    print('mono')
PYEOF
)

out=${XDG_RUNTIME_DIR:-/tmp}/tray-icons
mkdir -p "$out" 2>/dev/null || { out=/tmp/tray-icons; mkdir -p "$out"; }
# Render at the size it is drawn: 18px tinted for silhouettes, 22px for artwork.
if [ "$verdict" = mono ]; then sz=18; else sz=22; fi
if rsvg-convert -w $sz -h $sz -o "$out/$name.png" "$f" 2>/dev/null; then
    chmod 644 "$out/$name.png" 2>/dev/null
    echo "$verdict $out/$name.png"
else
    echo "art $f"
fi
