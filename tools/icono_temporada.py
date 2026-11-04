#!/usr/bin/env python3
"""Genera el icono de Mi Temporada (anillo de progreso y cima con bandera) sin dependencias externas.

Uso: python3 tools/icono_temporada.py watch-temporada/resources/launcher.png [tamaño]
Dibuja a 4x y reduce para suavizar los bordes.
"""
import math
import struct
import sys
import zlib

OUT = sys.argv[1] if len(sys.argv) > 1 else "watch-temporada/resources/launcher.png"
SIZE = int(sys.argv[2]) if len(sys.argv) > 2 else 70
SS = 4
N = SIZE * SS
K = N / 280.0  # el diseño está pensado en un lienzo de 280


def hexc(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255, 255)


OUTLINE = hexc(0x3B2416)
FUR = hexc(0xFFB347)
PINK = hexc(0xFF8FA3)
TEAL = hexc(0x00E5A8)
NAVY = hexc(0x14213D)
WHITE = hexc(0xFFFFFF)
PUPIL = hexc(0x1A1A1A)
MOUTH = hexc(0x6B1E2B)
TONGUE = hexc(0xFF6F8A)


def ellipse(cx, cy, rx, ry):
    cx, cy, rx, ry = cx * K, cy * K, rx * K, ry * K
    return lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def circle(cx, cy, r):
    return ellipse(cx, cy, r, r)


def ring(cx, cy, r0, r1):
    cx, cy, r0, r1 = cx * K, cy * K, r0 * K, r1 * K
    return lambda x, y: r0 * r0 <= (x - cx) ** 2 + (y - cy) ** 2 <= r1 * r1


def arc_band(cx, cy, r0, r1, a0, a1):
    cx, cy, r0, r1 = cx * K, cy * K, r0 * K, r1 * K

    def f(x, y):
        d2 = (x - cx) ** 2 + (y - cy) ** 2
        if not (r0 * r0 <= d2 <= r1 * r1):
            return False
        ang = math.degrees(math.atan2(cy - y, x - cx))  # 0 = derecha, 90 = arriba
        return any(a0 <= ang + k <= a1 for k in (-360, 0, 360))
    return f


def both(a, b):
    return lambda x, y: a(x, y) and b(x, y)


def below(yy):
    return lambda x, y: y >= yy * K


def triangle(ax, ay, bx, by, cx2, cy2):
    ax, ay, bx, by, cx2, cy2 = ax * K, ay * K, bx * K, by * K, cx2 * K, cy2 * K

    def f(x, y):
        d1 = (x - bx) * (ay - by) - (ax - bx) * (y - by)
        d2 = (x - cx2) * (by - cy2) - (bx - cx2) * (y - cy2)
        d3 = (x - ax) * (cy2 - ay) - (cx2 - ax) * (y - ay)
        neg = d1 < 0 or d2 < 0 or d3 < 0
        pos = d1 > 0 or d2 > 0 or d3 > 0
        return not (neg and pos)
    return f


def rect(x0, y0, x1, y1):
    return lambda x, y: x0 * K <= x <= x1 * K and y0 * K <= y <= y1 * K


DARK = hexc(0x0F1B33)
TRACK = hexc(0x23365C)
SNOW = hexc(0xFFFFFF)
SLOPE = hexc(0xC9D6EA)
ORANGE = hexc(0xFF7A3D)

# Logotipo: anillo de progreso de la temporada y una cima con bandera (los objetivos).
layers = [
    (circle(140, 140, 139), DARK),
    (ring(140, 140, 104, 124), TRACK),
    (arc_band(140, 140, 104, 124, -200, 70), TEAL),
    (circle(140 + 114 * math.cos(math.radians(70)), 140 - 114 * math.sin(math.radians(70)), 10), TEAL),
    (circle(140 + 114 * math.cos(math.radians(-200)), 140 - 114 * math.sin(math.radians(-200)), 10), TEAL),
    (triangle(62, 190, 112, 120, 158, 190), SLOPE),
    (triangle(96, 190, 150, 88, 214, 190), SNOW),
    (triangle(150, 88, 180, 145, 150, 190), SLOPE),
    (rect(148, 58, 153, 90), SNOW),
    (triangle(153, 58, 182, 67, 153, 77), ORANGE),
    (rect(62, 190, 214, 197), TEAL),
]

big = [[(0, 0, 0, 0)] * N for _ in range(N)]
for y in range(N):
    row = big[y]
    py = y + 0.5
    for x in range(N):
        px = x + 0.5
        for test, color in layers:
            if test(px, py):
                row[x] = color

# Reducción con promedio (antialiasing)
rows = []
for y in range(SIZE):
    line = bytearray([0])  # filtro PNG "None"
    for x in range(SIZE):
        r = g = b = a = 0
        for dy in range(SS):
            for dx in range(SS):
                c = big[y * SS + dy][x * SS + dx]
                r += c[0] * c[3]
                g += c[1] * c[3]
                b += c[2] * c[3]
                a += c[3]
        if a:
            line += bytes((r // a, g // a, b // a, a // (SS * SS)))
        else:
            line += bytes((0, 0, 0, 0))
    rows.append(bytes(line))


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
png += chunk(b"IEND", b"")
open(OUT, "wb").write(png)
print(f"Icono {SIZE}x{SIZE} -> {OUT}")
