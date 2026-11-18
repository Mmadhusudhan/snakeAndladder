#!/usr/bin/env python3
"""Draws the launcher icon (1024x1024) and an adaptive-icon foreground with
Pillow: jungle gradient tile, a coiled snake, a ladder and a dice.
Run from the repo root:  python3 tool/gen_icon.py
Then:  dart run flutter_launcher_icons
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "icon"
S = 1024


def gradient_tile(size, top=(63, 166, 107), bottom=(11, 42, 30)):
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(size):
            px[x, y] = (*c, 255)
    return img


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def bezier(p0, p1, p2, p3, n=400):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t**2 * p2[0] + t**3 * p3[0]
        y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def draw_ladder(d, a, b, width, rail=(140, 90, 43), dark=(90, 54, 23), rung=(176, 122, 62)):
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    gap = width / 2
    for sx, sy in [(nx * gap, ny * gap), (-nx * gap, -ny * gap)]:
        d.line([(a[0] + sx, a[1] + sy), (b[0] + sx, b[1] + sy)], fill=dark, width=int(width * 0.32))
        d.line([(a[0] + sx, a[1] + sy), (b[0] + sx, b[1] + sy)], fill=rail, width=int(width * 0.22))
    n = int(L / (width * 0.9))
    for i in range(1, n):
        t = i / n
        cx, cy = a[0] + dx * t, a[1] + dy * t
        d.line([(cx + nx * gap, cy + ny * gap), (cx - nx * gap, cy - ny * gap)], fill=dark, width=int(width * 0.26))
        d.line([(cx + nx * gap, cy + ny * gap), (cx - nx * gap, cy - ny * gap)], fill=rung, width=int(width * 0.16))


def draw_snake(d, pts, head_r, tail_r, body=(123, 63, 228), band=(96, 40, 190), belly=(217, 194, 255), outline=(60, 25, 120)):
    n = len(pts)
    for i in range(n - 1, -1, -1):
        t = i / (n - 1)
        r = head_r * (1 - t) + tail_r * t
        x, y = pts[i]
        d.ellipse([x - r - 4, y - r - 4, x + r + 4, y + r + 4], fill=outline)
    for i in range(n - 1, -1, -1):
        t = i / (n - 1)
        r = head_r * (1 - t) + tail_r * t
        x, y = pts[i]
        col = band if (i // 24) % 2 else body
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)
        hr = r * 0.42
        d.ellipse([x - r * 0.3 - hr, y - r * 0.3 - hr, x - r * 0.3 + hr, y - r * 0.3 + hr], fill=(*belly, 150))
    # Head
    hx, hy = pts[0]
    px, py = pts[12]
    ang = math.atan2(hy - py, hx - px)
    cx, cy = hx + math.cos(ang) * head_r * 0.5, hy + math.sin(ang) * head_r * 0.5
    hw, hh = head_r * 1.9, head_r * 1.45
    head = Image.new("RGBA", (int(hw * 2), int(hh * 2)), (0, 0, 0, 0))
    hd = ImageDraw.Draw(head)
    hd.ellipse([4, 4, hw * 2 - 4, hh * 2 - 4], fill=outline)
    hd.ellipse([12, 12, hw * 2 - 12, hh * 2 - 12], fill=body)
    # eyes
    for sy in (-1, 1):
        ex, ey = hw * 1.25, hh + sy * hh * 0.42
        er = head_r * 0.28
        hd.ellipse([ex - er - 4, ey - er - 4, ex + er + 4, ey + er + 4], fill=outline)
        hd.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(255, 255, 255))
        pr = er * 0.55
        hd.ellipse([ex + er * 0.25 - pr, ey - pr, ex + er * 0.25 + pr, ey + pr], fill=(30, 30, 30))
    # tongue
    tx = hw * 2 - 8
    hd.line([(tx - head_r * 0.3, hh), (tx + head_r * 0.7, hh)], fill=(229, 57, 80), width=int(head_r * 0.14))
    hd.line([(tx + head_r * 0.7, hh), (tx + head_r * 1.0, hh - head_r * 0.3)], fill=(229, 57, 80), width=int(head_r * 0.12))
    hd.line([(tx + head_r * 0.7, hh), (tx + head_r * 1.0, hh + head_r * 0.3)], fill=(229, 57, 80), width=int(head_r * 0.12))
    head = head.rotate(-math.degrees(ang), resample=Image.BICUBIC, expand=True)
    return head, (int(cx - head.width / 2), int(cy - head.height / 2))


def draw_dice(img, center, size, angle=-18):
    dice = Image.new("RGBA", (size + 80, size + 80), (0, 0, 0, 0))
    d = ImageDraw.Draw(dice)
    o = 40
    d.rounded_rectangle([o + 10, o + 16, o + size + 10, o + size + 16], radius=size * 0.2, fill=(0, 0, 0, 90))
    d.rounded_rectangle([o, o, o + size, o + size], radius=size * 0.2, fill=(255, 255, 255), outline=(150, 150, 150), width=6)
    pr = size * 0.085
    for px, py in [(0.25, 0.25), (0.75, 0.25), (0.5, 0.5), (0.25, 0.75), (0.75, 0.75)]:
        x, y = o + px * size, o + py * size
        d.ellipse([x - pr, y - pr, x + pr, y + pr], fill=(30, 30, 30))
    dice = dice.rotate(angle, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(dice, (int(center[0] - dice.width / 2), int(center[1] - dice.height / 2)))


def compose(size, with_background, padding):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if with_background:
        tile = gradient_tile(size)
        canvas.paste(tile, (0, 0), rounded_mask(size, int(size * 0.22)))
        # subtle inner glow ring
        ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(ring).rounded_rectangle([size * 0.03] * 2 + [size * 0.97] * 2, radius=int(size * 0.2), outline=(255, 200, 87, 120), width=int(size * 0.012))
        canvas.alpha_composite(ring)
    art = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(art)
    p = padding
    # Ladder (behind the snake)
    draw_ladder(d, (size * (0.28 + p), size * (0.86 - p)), (size * (0.62 - p), size * (0.16 + p)), width=size * (0.14 - p * 0.3))
    # Snake: S curve from top-right head to bottom-left tail
    pts = bezier((size * (0.74 - p), size * (0.24 + p)), (size * 1.05, size * 0.5), (size * -0.05, size * 0.62), (size * (0.3 + p), size * (0.88 - p)))
    head, pos = draw_snake(d, pts, head_r=size * (0.075 - p * 0.2), tail_r=size * 0.02)
    art.alpha_composite(head, pos)
    canvas.alpha_composite(art)
    draw_dice(canvas, (size * (0.76 - p), size * (0.74 - p)), int(size * (0.22 - p * 0.4)))
    return canvas


OUT.mkdir(parents=True, exist_ok=True)
compose(S, True, 0.0).save(OUT / "icon.png")
compose(S, False, 0.12).save(OUT / "icon_foreground.png")
# Web / store banner-friendly maskable: solid background with padded art
bg = gradient_tile(S)
bg.alpha_composite(compose(S, False, 0.12))
bg.save(OUT / "icon_maskable.png")
print("icons written to", OUT)
