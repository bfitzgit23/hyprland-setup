"""Turn colour artwork into a bar-sized silhouette: keep the coloured marks
only (an app icon's tile or plate is dropped), tint them, and scale them to the
draw size. Used for app icons such as RustDesk whose mark is a coloured ring on
a light plate."""
import struct
import sys
import zlib

src, dst, size = sys.argv[1], sys.argv[2], int(sys.argv[3])

data = open(src, 'rb').read()
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
    raise SystemExit(1)
bpp = 4 if color == 6 else 3
stride = w * bpp
raw = zlib.decompress(idat)
prev = bytearray(stride)
alpha = []
minx, miny, maxx, maxy = w, h, -1, -1
i = 0
for y in range(h):
    ft = raw[i]
    i += 1
    line = bytearray(raw[i:i + stride])
    i += stride
    for x in range(stride):
        a = line[x - bpp] if x >= bpp else 0
        b = prev[x]
        c = prev[x - bpp] if x >= bpp else 0
        if ft == 1:
            line[x] = (line[x] + a) & 0xFF
        elif ft == 2:
            line[x] = (line[x] + b) & 0xFF
        elif ft == 3:
            line[x] = (line[x] + (a + b) // 2) & 0xFF
        elif ft == 4:
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 0xFF
    prev = line
    row = []
    for x in range(0, stride, bpp):
        r, g, bl = line[x], line[x + 1], line[x + 2]
        keep = 255 if (max(r, g, bl) - min(r, g, bl) > 40 and line[x + 3] > 64) else 0
        row.append(keep)
        if keep:
            if x // bpp < minx:
                minx = x // bpp
            if x // bpp > maxx:
                maxx = x // bpp
            if y < miny:
                miny = y
            if y > maxy:
                maxy = y
    alpha.append(row)
if maxx < 0:
    raise SystemExit(1)

bw, bh = maxx - minx + 1, maxy - miny + 1
target = int(size * 0.9)
scale = min(target / float(bw), target / float(bh))
ow = max(1, int(round(bw * scale)))
oh = max(1, int(round(bh * scale)))
ox, oy = (size - ow) // 2, (size - oh) // 2
canvas = bytearray(size * size * 4)
for oy2 in range(oh):
    sy0 = miny + oy2 * bh // oh
    sy1 = max(miny + (oy2 + 1) * bh // oh, sy0 + 1)
    for ox2 in range(ow):
        sx0 = minx + ox2 * bw // ow
        sx1 = max(minx + (ox2 + 1) * bw // ow, sx0 + 1)
        tot = n = 0
        for sy in range(sy0, sy1):
            row = alpha[sy]
            for sx in range(sx0, sx1):
                tot += row[sx]
                n += 1
        if not n or not tot:
            continue
        d = ((oy + oy2) * size + (ox + ox2)) * 4
        canvas[d] = canvas[d + 1] = canvas[d + 2] = 255
        canvas[d + 3] = tot // n

payload = b''.join(b'\x00' + bytes(canvas[y * size * 4:(y + 1) * size * 4]) for y in range(size))
def chunk(tag, body):
    return struct.pack('>I', len(body)) + tag + body + struct.pack('>I', zlib.crc32(tag + body) & 0xFFFFFFFF)
open(dst, 'wb').write(b'\x89PNG\r\n\x1a\n'
                      + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
                      + chunk(b'IDAT', zlib.compress(payload, 9))
                      + chunk(b'IEND', b''))
