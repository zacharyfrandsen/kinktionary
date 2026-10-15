#!/usr/bin/env python3
"""Generate the seamless wallpaper tile used behind every screen.

Writes assets/images/pattern_tile.png: white silhouettes on a transparent
background. The app tints it per theme, so the icon colour is set in Dart
(see lib/widgets/pattern_background.dart), not here.

All icons are drawn from scratch in this file. Tweak ORDER / ROT / SCALE to
rearrange, resize or swap them, then re-run:

    python3 -I tools/make_pattern.py            (needs Pillow)

Optional: pass a directory to also write grey-on-black preview images there.
"""
import math
import pathlib
import random
import sys

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images" / "pattern_tile.png"

TILE = 1200      # output tile, pixels (shown at 1/3 size in the app)
SS = 8           # supersampling used while drawing each icon
MARGIN = 10      # padding around each 100x100 icon box, in design units
SIZE = 100 + 2 * MARGIN


# ---------------------------------------------------------------- geometry
def bez(p0, p1, p2, p3, n=48):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((
            u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
            u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
        ))
    return pts


def chain(start, *segs):
    """Build a polyline from ('L', pt) and ('C', c1, c2, end) segments."""
    pts = [start]
    for s in segs:
        if s[0] == "L":
            pts.append(s[1])
        else:
            pts.extend(bez(pts[-1], s[1], s[2], s[3])[1:])
    return pts


def leaf(base, angle_deg, length, width):
    a = math.radians(angle_deg)          # 0 = pointing up
    dx, dy = math.sin(a), -math.cos(a)
    nx, ny = -dy, dx
    left, right = [], []
    for i in range(25):
        t = i / 24
        w = width * math.sin(math.pi * t**0.8)
        cx, cy = base[0] + dx * length * t, base[1] + dy * length * t
        left.append((cx + nx * w, cy + ny * w))
        right.append((cx - nx * w, cy - ny * w))
    return left + right[::-1]


# ------------------------------------------------------------------ canvas
class Canvas:
    def __init__(self):
        self.img = Image.new("L", (SIZE * SS, SIZE * SS), 0)
        self.d = ImageDraw.Draw(self.img)

    def _p(self, pt):
        return ((pt[0] + MARGIN) * SS, (pt[1] + MARGIN) * SS)

    def poly(self, pts, fill=255):
        self.d.polygon([self._p(p) for p in pts], fill=fill)

    def line(self, pts, w, fill=255):
        pp = [self._p(p) for p in pts]
        wd = max(1, round(w * SS))
        r = wd / 2
        self.d.line(pp, fill=fill, width=wd, joint="curve")
        for x, y in (pp[0], pp[-1]):
            self.d.ellipse([x - r, y - r, x + r, y + r], fill=fill)

    def disc(self, c, r, fill=255):
        x, y = self._p(c)
        R = r * SS
        self.d.ellipse([x - R, y - R, x + R, y + R], fill=fill)

    def ring(self, c, r, w):
        x, y = self._p(c)
        R = (r + w / 2) * SS
        self.d.ellipse([x - R, y - R, x + R, y + R], outline=255, width=round(w * SS))

    def taper(self, pts, w0, w1):
        n = len(pts) - 1
        for i in range(n):
            self.line([pts[i], pts[i + 1]], w0 + (w1 - w0) * i / n)

    def oval(self, box, fill=255):
        x0, y0 = self._p(box[:2])
        x1, y1 = self._p(box[2:])
        self.d.ellipse([x0, y0, x1, y1], fill=fill)

    def oval_ring(self, box, w):
        h = w / 2
        x0, y0 = self._p((box[0] - h, box[1] - h))
        x1, y1 = self._p((box[2] + h, box[3] + h))
        self.d.ellipse([x0, y0, x1, y1], outline=255, width=round(w * SS))

    def rrect(self, box, r, fill=255):
        x0, y0 = self._p(box[:2])
        x1, y1 = self._p(box[2:])
        self.d.rounded_rectangle([x0, y0, x1, y1], radius=r * SS, fill=fill)

    def rrect_ring(self, box, r, w):
        h = w / 2
        x0, y0 = self._p((box[0] - h, box[1] - h))
        x1, y1 = self._p((box[2] + h, box[3] + h))
        self.d.rounded_rectangle([x0, y0, x1, y1], radius=(r + h) * SS,
                                 outline=255, width=round(w * SS))


# ------------------------------------------------------------------- icons
def handcuffs(c):
    c.ring((27, 66), 16, 7)
    c.ring((73, 66), 16, 7)
    c.rrect((19, 38, 35, 52), 4)
    c.rrect((65, 38, 81, 52), 4)
    for t in (0.12, 0.34, 0.5, 0.66, 0.88):      # chain links along an arc
        u = 1 - t
        x = u * u * 33 + 2 * u * t * 50 + t * t * 67
        y = u * u * 42 + 2 * u * t * 12 + t * t * 42
        c.ring((x, y), 5, 3)


def feather(c):
    c.line([(50, 97), (50, 64)], 6)
    for ang, ln in ((-28, 52), (28, 52), (0, 64)):
        c.poly(leaf((50, 66), ang, ln, 9))
        a = math.radians(ang)
        dx, dy = math.sin(a), -math.cos(a)
        c.line([(50 + dx * ln * 0.12, 66 + dy * ln * 0.12),
                (50 + dx * ln * 0.9, 66 + dy * ln * 0.9)], 1.5, fill=0)


def twist(c, pts, half_w):
    """Erase short slanted marks across a thick stroke so it reads as twisted rope."""
    for i in range(2, len(pts) - 2, 4):
        dx, dy = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
        n = math.hypot(dx, dy) or 1
        dx, dy = dx / n, dy / n
        nx, ny = -dy, dx
        x, y = pts[i]
        c.line([(x - nx * half_w - dx * 1.6, y - ny * half_w - dy * 1.6),
                (x + nx * half_w + dx * 1.6, y + ny * half_w + dy * 1.6)], 1.6, fill=0)


def rope(c):
    rings = []
    for R in (37, 25, 13):
        c.ring((50, 50), R, 9)
        rings.append([(50 + R * math.cos(i / 90 * math.pi * 2),
                       50 + R * math.sin(i / 90 * math.pi * 2)) for i in range(91)])
    tail = chain((78, 76), ("C", (86, 86), (80, 96), (94, 98)))
    c.line(tail, 9)
    for pts in rings:
        twist(c, pts, 4.6)
    twist(c, tail, 4.6)


def paddle(c):
    c.rrect((30, 6, 70, 58), 12)
    c.rrect((44, 54, 56, 95), 5)
    for y in (18, 31, 44):
        for x in (40, 50, 60):
            c.disc((x, y), 2.8, fill=0)


def flogger(c):
    c.rrect((43, 62, 57, 97), 5)
    for a in (-36, -24, -12, 0, 12, 24, 36):
        end = (50 + a * 1.5, 8 + abs(a) * 0.4)
        c.line(bez((50, 64), (50 + a * 0.25, 46), (50 + a * 1.1, 30), end), 3)


def crop(c):
    c.line([(50, 80), (50, 22)], 4.5)
    c.rrect((45, 58, 55, 86), 4)              # grip
    c.oval_ring((41, 82, 59, 101), 4)         # wrist loop
    c.poly([(40, 30), (60, 30), (57, 3), (43, 3)])   # leather tab


def collar(c):
    c.oval_ring((10, 30, 90, 62), 8)
    for deg in range(20, 161, 28):            # studs along the front of the band
        a = math.radians(deg)
        c.disc((50 + 40 * math.cos(a), 46 + 16 * math.sin(a)), 1.7, fill=0)
    c.rrect((43, 56, 57, 72), 3)
    c.line([(50, 72), (50, 75)], 4)
    c.ring((50, 84), 8, 4)


def heel(c):
    body = chain((4, 72),
                 ("C", (10, 60), (26, 56), (38, 50)),
                 ("C", (54, 44), (60, 30), (64, 18)),
                 ("L", (84, 22)),
                 ("C", (88, 34), (86, 48), (80, 60)),
                 ("C", (64, 70), (42, 76), (24, 76)),
                 ("C", (12, 77), (4, 76), (4, 72)))
    c.poly(body)
    c.line([(79, 62), (87, 97)], 5)


def boot(c):
    shape = chain((24, 4),
                  ("L", (66, 4)),
                  ("C", (64, 30), (58, 46), (58, 62)),
                  ("C", (68, 66), (86, 70), (92, 80)),
                  ("C", (94, 86), (90, 90), (84, 90)),
                  ("L", (40, 90)),
                  ("L", (40, 97)),
                  ("L", (26, 97)),
                  ("L", (26, 84)),
                  ("C", (30, 70), (34, 56), (32, 40)),
                  ("C", (30, 26), (26, 14), (24, 4)))
    c.poly(shape)


def mask(c):
    shape = chain((8, 46),
                  ("C", (20, 30), (34, 38), (50, 44)),
                  ("C", (66, 38), (80, 30), (92, 46)),
                  ("C", (90, 62), (76, 72), (62, 62)),
                  ("C", (56, 58), (54, 56), (50, 56)),
                  ("C", (46, 56), (44, 58), (38, 62)),
                  ("C", (24, 72), (10, 62), (8, 46)))
    c.poly(shape)
    c.oval((22, 44, 38, 56), fill=0)
    c.oval((62, 44, 78, 56), fill=0)
    c.line([(8, 46), (0, 40)], 4)
    c.line([(92, 46), (100, 40)], 4)


def pinwheel(c):
    c.line([(50, 97), (50, 52)], 6)
    c.disc((50, 34), 9)
    for i in range(12):
        a = math.radians(i * 30)
        c.line([(50 + 11 * math.cos(a), 34 + 11 * math.sin(a)),
                (50 + 23 * math.cos(a), 34 + 23 * math.sin(a))], 3.2)
    c.disc((50, 34), 3, fill=0)


def padlock(c):
    arc = [(34, 48), (34, 30)]
    for i in range(1, 24):
        a = math.pi + math.pi * i / 24
        arc.append((50 + 16 * math.cos(a), 30 + 16 * math.sin(a)))
    arc += [(66, 30), (66, 48)]
    c.line(arc, 7)
    c.rrect((24, 44, 76, 90), 9)
    c.disc((50, 63), 5.5, fill=0)
    c.poly([(47.5, 66), (52.5, 66), (54.5, 80), (45.5, 80)], fill=0)


def candle(c):
    c.rrect_ring((36, 40, 64, 94), 5, 5)
    c.rrect((36, 38, 64, 50), 4)
    c.oval((40, 44, 47, 62))
    c.oval((53, 44, 60, 66))
    flame = chain((50, 4),
                  ("C", (62, 18), (64, 28), (50, 33)),
                  ("C", (36, 28), (38, 18), (50, 4)))
    c.poly(flame)
    c.line([(50, 33), (50, 39)], 3)


def corset(c):
    outline = chain((26, 10),
                    ("C", (22, 30), (36, 40), (34, 50)),
                    ("C", (32, 62), (20, 72), (24, 90)),
                    ("L", (76, 90)),
                    ("C", (80, 72), (68, 62), (66, 50)),
                    ("C", (64, 40), (78, 30), (74, 10)),
                    ("L", (26, 10)))
    c.line(outline, 5)
    for y in (20, 32, 44, 56, 68):
        c.line([(43, y), (57, y + 11)], 3.2)
        c.line([(57, y), (43, y + 11)], 3.2)


def key(c):
    c.ring((28, 28), 15, 7)
    c.line([(39, 39), (86, 86)], 7)
    c.line([(70, 70), (80, 60)], 6)
    c.line([(80, 80), (90, 70)], 6)


def heart(c):
    shape = chain((50, 88),
                  ("C", (10, 58), (4, 30), (26, 20)),
                  ("C", (38, 14), (48, 22), (50, 30)),
                  ("C", (52, 22), (62, 14), (74, 20)),
                  ("C", (96, 30), (90, 58), (50, 88)))
    c.poly(shape)


def whip(c):
    c.line([(16, 94), (38, 60)], 8)           # handle
    tail = chain((38, 60),
                 ("C", (60, 28), (90, 56), (74, 30)),
                 ("C", (62, 10), (40, 22), (30, 8)))
    c.taper(tail, 5, 1.5)


def sparkle(c):
    pts = []
    for i in range(8):
        r = 44 if i % 2 == 0 else 11
        a = math.radians(i * 45 - 90)
        pts.append((50 + r * math.cos(a), 50 + r * math.sin(a)))
    c.poly(pts)


ICONS = {f.__name__: f for f in (
    handcuffs, feather, rope, paddle, flogger, crop, collar, heel, boot, mask,
    pinwheel, padlock, candle, corset, key, whip, heart, sparkle)}

# ------------------------------------------------------------------ layout
ORDER = [
    "handcuffs", "feather", "heel", "paddle",
    "rope", "pinwheel", "collar", "flogger",
    "candle", "corset", "key", "crop",
    "boot", "mask", "padlock", "whip",
]
ROT = {"handcuffs": -12, "feather": 28, "heel": -18, "paddle": -25, "rope": 8,
       "pinwheel": 35, "collar": -8, "flogger": -30, "candle": 15, "corset": -10,
       "key": -15, "crop": 32, "boot": 12, "mask": -10, "padlock": 14, "whip": 10}
SCALE = {"rope": 2.05, "mask": 2.0, "candle": 2.05, "key": 2.1, "whip": 2.1}
DEFAULT_SCALE = 2.2       # output pixels per design unit
CELL = TILE // 4          # 4 x 4 grid, alternate rows shifted by half a cell


def render_mask(name):
    c = Canvas()
    ICONS[name](c)
    return c.img


def place(tile, mask_img, cx, cy, angle, u):
    m = mask_img.rotate(angle, resample=Image.BICUBIC, expand=True)
    px = round(m.width / (SIZE * SS) * SIZE * u)
    m = m.resize((px, px), Image.LANCZOS)
    solid = Image.new("L", m.size, 255)
    for dx in (-TILE, 0, TILE):          # wrap around so the tile repeats seamlessly
        for dy in (-TILE, 0, TILE):
            x = round(cx - px / 2 + dx)
            y = round(cy - px / 2 + dy)
            if x + px <= 0 or y + px <= 0 or x >= TILE or y >= TILE:
                continue
            tile.paste(solid, (x, y), m)


def build():
    rng = random.Random(11)
    tile = Image.new("L", (TILE, TILE), 0)
    masks = {n: render_mask(n) for n in set(ORDER) | {"heart", "sparkle"}}

    xs = {}
    for i, name in enumerate(ORDER):
        r, col = divmod(i, 4)
        cx = CELL // 2 + CELL * col + (r % 2) * (CELL // 2) + rng.uniform(-20, 20)
        cy = CELL // 2 + CELL * r + rng.uniform(-20, 20)
        xs[(r, col)] = cx
        ang = ROT.get(name, 0) + rng.uniform(-6, 6)
        place(tile, masks[name], cx, cy, ang, SCALE.get(name, DEFAULT_SCALE))

    # small fillers in the gaps between rows
    k = 0
    for r in range(4):
        for col in (0, 2):
            cx = xs[(r, col)] + CELL // 4
            cy = CELL // 2 + CELL * r + CELL // 2
            name = ("heart", "sparkle")[k % 2]
            k += 1
            place(tile, masks[name], cx, cy, rng.uniform(-20, 20),
                  0.75 if name == "heart" else 0.8)
    return tile


def save(tile):
    rgba = Image.new("RGBA", tile.size, (255, 255, 255, 0))
    rgba.putalpha(tile)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    rgba.save(OUT, optimize=True)
    print("wrote", OUT.relative_to(ROOT), f"({OUT.stat().st_size // 1024} KB)")


def previews(tile, folder):
    folder = pathlib.Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    base = (14, 14, 16)

    def compose(alpha_scale, tiles):
        a = tile.point(lambda v: int(v * alpha_scale))
        one = Image.new("RGB", tile.size, base)
        one.paste(Image.new("RGB", tile.size, (255, 255, 255)), (0, 0), a)
        big = Image.new("RGB", (TILE * tiles, TILE * tiles))
        for i in range(tiles):
            for j in range(tiles):
                big.paste(one, (i * TILE, j * TILE))
        return big

    compose(0.36, 2).resize((1400, 1400), Image.LANCZOS).save(folder / "preview_reference_look.png")
    compose(0.20, 2).resize((1400, 1400), Image.LANCZOS).save(folder / "preview_in_app_look.png")
    print("previews in", folder)


if __name__ == "__main__":
    t = build()
    save(t)
    if len(sys.argv) > 1:
        previews(t, sys.argv[1])
