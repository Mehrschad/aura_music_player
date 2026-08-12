#!/usr/bin/env python3
"""Generates Aura's launcher icons from the in-app brand mark.

The mark is `AuraMark` (lib/presentation/widgets/aurora_mark.dart): a centre dot
plus three concentric rings at decreasing opacity, filled with the AuroraColors
ribbon. This script reproduces it as launcher art so the icon and the header
mark are the same drawing.

Outputs:
  * legacy square + round mipmaps (API 21-25) as PNG
  * a 512px master for store listings / previews

Adaptive icons (API 26+) are hand-written vector drawables in
android/app/src/main/res/ - they are resolution independent, so they are not
generated here.

Pure standard library: no Pillow, no ImageMagick. PNG is a simple enough format
to emit directly, and the artwork is circles, so a supersampling rasteriser is
all it needs.
"""

import math
import os
import struct
import sys
import zlib

# ── Brand ────────────────────────────────────────────────────────────────────
# AuroraColors: teal-mint -> sky blue -> violet -> soft magenta, at 115 degrees.
AURORA = [
    (0.00, (0x5E, 0xE7, 0xC8)),
    (0.38, (0x4A, 0xA8, 0xFF)),
    (0.72, (0x9A, 0x7B, 0xFF)),
    (1.00, (0xFF, 0x8F, 0xD0)),
]
# Near-black with a faint cool cast: pure #000 reads as a hole in the icon grid
# on dark launchers, and as a smudge on light ones.
BG_INNER = (0x11, 0x1C, 0x24)
BG_OUTER = (0x06, 0x0A, 0x0E)

# Mark geometry, as fractions of the mark's radius - from AuraMark, with the
# ring opacities lifted. In-app the mark sits on a raised surface at 26px; as a
# launcher tile on near-black the 0.24 outer ring simply disappeared, so the
# falloff is compressed to keep the hierarchy while staying legible at 48px.
DOT = 4 / 32
RINGS = [(11 / 32, 1.0), (19 / 32, 0.80), (27 / 32, 0.56)]
STROKE = 3.8 / 32

SS = 4  # supersampling factor per axis


def lerp(a, b, t):
    return a + (b - a) * t


def aurora_at(t):
    """Colour along the aurora ribbon at position t in [0,1]."""
    t = min(max(t, 0.0), 1.0)
    for i in range(len(AURORA) - 1):
        t0, c0 = AURORA[i]
        t1, c1 = AURORA[i + 1]
        if t <= t1:
            k = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
            return tuple(lerp(c0[j], c1[j], k) for j in range(3))
    return AURORA[-1][1]


def write_png(path, size, pixels):
    """pixels: flat list of (r,g,b,a) ints, row-major."""
    raw = bytearray()
    for y in range(size):
        raw.append(0)  # filter: none
        for x in range(size):
            r, g, b, a = pixels[y * size + x]
            raw += bytes((int(r), int(g), int(b), int(a)))

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(png)


def rounded_square_inside(nx, ny, radius):
    """Coverage test for a rounded square spanning the full [-1,1] box."""
    ax, ay = abs(nx), abs(ny)
    lim = 1.0 - radius
    if ax <= lim or ay <= lim:
        return ax <= 1.0 and ay <= 1.0
    dx, dy = ax - lim, ay - lim
    return dx * dx + dy * dy <= radius * radius


def render(size, shape, mark_scale):
    """shape: 'square' (rounded) or 'circle'. mark_scale: mark radius / half-size."""
    pixels = [(0, 0, 0, 0)] * (size * size)
    half = size / 2.0
    mark_r = half * mark_scale
    dot_r = mark_r * DOT
    stroke_w = mark_r * STROKE

    for py in range(size):
        for px in range(size):
            acc_r = acc_g = acc_b = acc_a = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    x = px + (sx + 0.5) / SS
                    y = py + (sy + 0.5) / SS
                    nx = (x - half) / half
                    ny = (y - half) / half

                    if shape == "circle":
                        inside = nx * nx + ny * ny <= 1.0
                    else:
                        inside = rounded_square_inside(nx, ny, 0.42)
                    if not inside:
                        continue

                    # Background: soft radial from a lifted centre to near-black,
                    # so the tile has depth instead of reading as flat paint.
                    d = min(math.hypot(nx, ny) / 1.414, 1.0)
                    fall = d ** 1.25
                    r = lerp(BG_INNER[0], BG_OUTER[0], fall)
                    g = lerp(BG_INNER[1], BG_OUTER[1], fall)
                    b = lerp(BG_INNER[2], BG_OUTER[2], fall)

                    # Mark, in mark-local pixels from the centre.
                    dist = math.hypot(x - half, y - half)

                    # Ribbon position, measured across the *mark* rather than
                    # the whole tile: spanning the tile squeezed every ring into
                    # the blue middle of the gradient and lost the teal and the
                    # magenta entirely.
                    mx = (x - half) / mark_r
                    my = (y - half) / mark_r
                    t = (mx * 0.9 + my * 0.7) / 3.2 + 0.5
                    mr, mg, mb = aurora_at(t)

                    # Aura: a soft bloom behind the rings, so the mark glows
                    # rather than sitting on the tile as flat paint.
                    glow = 0.30 * math.exp(-((dist / (mark_r * 0.78)) ** 2))
                    r = lerp(r, mr, glow)
                    g = lerp(g, mg, glow)
                    b = lerp(b, mb, glow)

                    alpha = 0.0
                    if dist <= dot_r:
                        alpha = 1.0
                    else:
                        for factor, op in RINGS:
                            ring_r = mark_r * factor
                            edge = abs(dist - ring_r)
                            if edge <= stroke_w / 2:
                                alpha = max(alpha, op)

                    if alpha > 0:
                        r = lerp(r, mr, alpha)
                        g = lerp(g, mg, alpha)
                        b = lerp(b, mb, alpha)

                    acc_r += r
                    acc_g += g
                    acc_b += b
                    acc_a += 255.0

            n = SS * SS
            cov = acc_a / (n * 255.0)
            if cov <= 0:
                continue
            # Un-premultiply so edges stay clean against any launcher backdrop.
            pixels[py * size + px] = (
                acc_r / (n * cov),
                acc_g / (n * cov),
                acc_b / (n * cov),
                round(cov * 255),
            )
    return pixels


# Legacy launcher densities. Adaptive icons cover API 26+; these are the
# fallback for Android 5.0-7.1, which minSdk 21 still admits.
DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    res = os.path.join(root, "android/app/src/main/res")

    for bucket, size in DENSITIES.items():
        write_png(
            os.path.join(res, f"mipmap-{bucket}/ic_launcher.png"),
            size,
            render(size, "square", 0.62),
        )
        write_png(
            os.path.join(res, f"mipmap-{bucket}/ic_launcher_round.png"),
            size,
            render(size, "circle", 0.58),
        )
        print(f"  mipmap-{bucket}: {size}x{size}")

    master = os.path.join(root, "docs/icon/aura_icon_512.png")
    write_png(master, 512, render(512, "square", 0.62))
    print(f"  {master}")


if __name__ == "__main__":
    main()
