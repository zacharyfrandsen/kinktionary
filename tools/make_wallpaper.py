"""Builds the app's tiled wallpaper from the icon sheets.

Every `data_source/background_icons_sheet*.png` is artwork: icons laid out by
hand, either black on white paper or white on nothing. The app draws a tiled,
white-on-transparent version of them, so this:

  1. cuts every icon out of every sheet as its own patch (its alpha is the
     icon's ink, so anti-aliased edges stay smooth),
  2. drops an icon from a later sheet when it repeats one already taken,
  3. scales the rest by one factor, which keeps the designer's relative sizes,
  4. lays them into the tile, shuffled and one per cell, each turned and nudged
     a little inside its cell.

No icon touches the tile edge, so nothing is sliced by the repeat: every tile
boundary falls in an empty gap, and that gap is the same width as every other
gap between icons. That is what keeps the pattern free of both seams and
overlapping shapes.

    python3 tools/make_wallpaper.py [--check]

Needs Pillow, numpy and scipy:

    python3 -m venv /tmp/wpenv && /tmp/wpenv/bin/pip install pillow numpy scipy
    /tmp/wpenv/bin/python tools/make_wallpaper.py

With --check it writes /tmp/wallpaper_preview.png instead of the asset (the
tile repeated 2x2, the way it sits on screen) and prints what it would skip.
"""

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SHEETS = sorted((ROOT / 'data_source').glob('background_icons_sheet*.png'))
ASSET = ROOT / 'assets/images/background_icons_seamless.png'

TILE = (2200, 1700)      # the tile the app repeats
INSET = 30               # space kept between an icon and its cell edge
INK = 16                 # alpha above this counts as ink
SPECK = 600              # ink this small is a loose fleck, not part of an icon
# How far apart two marks can be and still be one icon. A sparse sheet leaves
# wide gutters; a dense one needs a shorter reach or neighbours merge.
REACH = {'': 26, 'sheet_2': 4}
# A couple of the sheet's drawings are packed against each other instead of
# sitting in a cell of their own: a tassel pair is drawn with a gender symbol
# pressed against its cord, and a cuff set with another. The growth step takes
# each pair for a single icon, and on the wall it reads as two toys crowding
# each other. Every one of those shapes is drawn on its own elsewhere on the
# sheets, so the crowded copies are left out. Rects are x0, y0, x1, y1 in that
# sheet's pixels.
CROWDED = {
    'background_icons_sheet_2.png': [(379, 1034, 1366, 2245),
                                     (3598, 2250, 4154, 2985)],
}
SEED = 20261030
TILT = 20                # icons are turned by up to this many degrees either way
SWAY = 0.12              # and sized from -12% to +12% of the shared scale
ROW_SWAY = 0.12          # each row slides sideways by up to this share of a cell
FILL = 0.42              # icon size against the average space each one gets
SPREAD = 140             # tries per icon when looking for the roomiest spot
SAME_ICON = 0.90         # similarity above which a later sheet repeats an icon


def load_sheet(path):
    """One sheet as an alpha mask: the icon's ink is opaque, everything else 0."""
    sheet = Image.open(path).convert('RGBA')
    pixels = np.asarray(sheet).astype(np.int32)
    alpha = pixels[:, :, 3]
    rgb = pixels[:, :, :3]
    luma = (rgb[:, :, 0] * 299 + rgb[:, :, 1] * 587 + rgb[:, :, 2] * 114) // 1000
    if (alpha < 250).mean() > 0.05:
        # Drawn on a transparent sheet: the painted pixels are the icons.
        ink = alpha
    else:
        # Drawn on white paper: the ink is whatever is darker than the paper.
        ink = 255 - luma
    return np.clip(ink, 0, 255).astype(np.uint8)


def cut_icons(alpha, reach):
    """Every icon on a sheet, as a tight alpha patch."""
    ink = alpha > INK

    # Grow the ink before labelling, so the marks one icon is drawn from join
    # up while the empty gutter between two icons stays a gutter. A fleck is not
    # part of any icon, but while it is in the mask it still joins things: the
    # growth step bridges through it, which is why the sheet's crowded corner
    # needs its divider below.
    groups, _ = ndimage.label(ndimage.binary_dilation(ink, iterations=reach))
    marks, count = ndimage.label(ink)

    # One pass over the marks, not one pass per icon: the sheet is 20 million
    # pixels and there are dozens of icons on it.
    slices = ndimage.find_objects(marks)
    areas = ndimage.sum(ink, marks, range(1, count + 1))
    per_group = {}
    for index, box in enumerate(slices, start=1):
        if box is None or areas[index - 1] < SPECK:
            continue
        # Any pixel of the mark names its group: the mark is connected ink, so
        # it lies wholly inside one grown group. The middle of the bounding box
        # is not safe -- for a horseshoe it falls in the hole.
        inside = np.argwhere(marks[box] == index)
        if inside.size == 0:
            continue
        py, px = inside[0]
        group = int(groups[box[0].start + py, box[1].start + px])
        per_group.setdefault(group, []).append((index, box))

    icons = []
    for pieces in per_group.values():
        y0 = min(p[1][0].start for p in pieces)
        y1 = max(p[1][0].stop for p in pieces)
        x0 = min(p[1][1].start for p in pieces)
        x1 = max(p[1][1].stop for p in pieces)
        keep = np.zeros((y1 - y0, x1 - x0), dtype=bool)
        for index, box in pieces:
            keep[box[0].start - y0:box[0].stop - y0,
                 box[1].start - x0:box[1].stop - x0] |= marks[box] == index
        if keep.sum() < SPECK:
            continue
        patch = np.where(keep, alpha[y0:y1, x0:x1], 0)
        icons.append({'patch': patch, 'box': (x0, y0, x1, y1)})
    return icons


def crowded(icon, rects):
    """True when this patch is one of the drawings CROWDED says to leave out."""
    x0, y0, x1, y1 = icon['box']
    return any(x0 >= rx0 - 40 and y0 >= ry0 - 40 and x1 <= rx1 + 40 and y1 <= ry1 + 40
               for rx0, ry0, rx1, ry1 in rects)


def signature(patch):
    """A 16x16 thumbprint of an icon, so a redraw of it can be recognised."""
    thumb = np.asarray(Image.fromarray(patch, 'L').resize((16, 16), Image.LANCZOS),
                       dtype=np.float32).ravel()
    norm = float(np.linalg.norm(thumb))
    return thumb / norm if norm else thumb


def similar(a, b):
    return float(np.dot(a, b))


def collect():
    """Icons from every sheet, without the ones a later sheet redraws."""
    icons = []
    skipped = []
    for path in SHEETS:
        reach = next((r for tag, r in REACH.items() if tag and tag in path.name),
                     REACH[''])
        sheet_icons = cut_icons(load_sheet(path), reach)
        rects = CROWDED.get(path.name, [])
        kept = [icon for icon in sheet_icons if not crowded(icon, rects)]
        if len(kept) != len(sheet_icons):
            print(f'{path.name}: leaving out {len(sheet_icons) - len(kept)} crowded'
                  ' drawing(s)')
        for icon in kept:
            sig = signature(icon['patch'])
            match = max((similar(sig, kept['sig']) for kept in icons), default=0.0)
            if match >= SAME_ICON:
                skipped.append((path.name, match))
                continue
            icon['sig'] = sig
            icons.append(icon)
        print(f'{path.name}: {len(sheet_icons)} icons')
    if skipped:
        print(f'skipping {len(skipped)} already on an earlier sheet')
    return icons


def wrap_gap(a, b, tile_w, tile_h):
    """Space between two icons measured across the tile edges too.

    The tile repeats, so the icon nearest the right edge also sits beside the
    icon nearest the left edge of the next copy. Measuring that gap the same
    way as the rest keeps the spacing even across the join.
    """
    ax, ay, ar = a
    bx, by, br = b
    dx = abs(ax - bx)
    dy = abs(ay - by)
    dx = min(dx, tile_w - dx)
    dy = min(dy, tile_h - dy)
    return (dx * dx + dy * dy) ** 0.5 - ar - br


def build():
    icons = collect()
    tile_w, tile_h = TILE
    # One icon is a boot on a stand, another a tiny plug: scaling by the largest
    # would shrink the whole field to suit the outlier, so the median icon sets
    # the size.
    median_w = float(np.median([i['patch'].shape[1] for i in icons]))
    median_h = float(np.median([i['patch'].shape[0] for i in icons]))
    room = (tile_w * tile_h / len(icons)) ** 0.5
    scale = FILL * room / max(median_w, median_h)

    rng = random.Random(SEED)
    # The sheets' order is how the icons were drawn, not how they should sit on
    # the wall: shuffling means neighbouring icons on the tile are not
    # neighbouring icons on a sheet, and a row of similar shapes never forms.
    rng.shuffle(icons)
    # Big icons first: a large shape squeezed in last has nowhere good to go.
    icons.sort(key=lambda i: -max(i['patch'].shape))

    tile = np.zeros((tile_h, tile_w), dtype=np.uint8)
    placed = []      # (centre x, centre y, radius)
    boxes = []
    for icon in icons:
        patch = Image.fromarray(icon['patch'], 'L')
        # Every icon gets its own tilt and its own size inside the sway band.
        own = scale * rng.uniform(1 - SWAY, 1 + SWAY)
        patch = patch.rotate(rng.uniform(-TILT, TILT), resample=Image.BICUBIC,
                             expand=True)
        w = max(1, int(round(patch.width * own)))
        h = max(1, int(round(patch.height * own)))
        limit_w, limit_h = tile_w - 2 * INSET, tile_h - 2 * INSET
        if w > limit_w or h > limit_h:  # a turned, oversized icon still fits
            shrink = min(limit_w / w, limit_h / h)
            w, h = max(1, int(w * shrink)), max(1, int(h * shrink))
        scaled = np.asarray(patch.resize((w, h), Image.LANCZOS))

        # No rows or columns: try a spread of spots and take the one furthest
        # from every icon already down. That gives an even scatter without the
        # lattice a grid leaves behind.
        # Half the diagonal, so the circle really does contain the icon; half
        # the longest side would let two turned icons clip at the corners.
        radius = math.hypot(w, h) / 2
        best = None
        for _ in range(SPREAD):
            left = rng.uniform(INSET, tile_w - INSET - w)
            top = rng.uniform(INSET, tile_h - INSET - h)
            cx, cy = left + w / 2, top + h / 2
            gap = min((wrap_gap((cx, cy, radius), other, tile_w, tile_h)
                       for other in placed), default=float('inf'))
            if best is None or gap > best[0]:
                best = (gap, left, top)
        _gap, left, top = best
        left, top = int(round(left)), int(round(top))
        tile[top:top + h, left:left + w] = np.maximum(
            tile[top:top + h, left:left + w], scaled)
        placed.append((left + w / 2, top + h / 2, radius))
        boxes.append((left, top, left + w, top + h))

    check(boxes, tile)
    gaps = sorted(wrap_gap(a, b, tile_w, tile_h)
                  for i, a in enumerate(placed) for b in placed[i + 1:])
    return tile, len(icons), (len(icons), gaps[len(gaps) // 20] if gaps else 0), scale


def check(placed, tile):
    """Fails loudly rather than shipping a tile with a seam or a collision."""
    tile_h, tile_w = tile.shape
    for (x0, y0, x1, y1) in placed:
        if x0 < 1 or y0 < 1 or x1 > tile_w - 1 or y1 > tile_h - 1:
            raise SystemExit(f'icon at {(x0, y0, x1, y1)} touches the tile edge')
    boxes = sorted(placed)
    for i, a in enumerate(boxes):
        for b in boxes[i + 1:]:
            if b[0] >= a[2]:
                break
            if a[1] < b[3] and b[1] < a[3]:
                raise SystemExit(f'icons overlap: {a} and {b}')


def write(tile, path):
    out = np.zeros((tile.shape[0], tile.shape[1], 4), dtype=np.uint8)
    out[:, :, :3] = 255
    out[:, :, 3] = tile
    Image.fromarray(out, 'RGBA').save(path, optimize=True)


def preview(tile, path):
    """The tile 2x2, tinted the way the app draws it over its background."""
    h, w = tile.shape
    canvas = np.tile(tile, (2, 2))
    backdrop = Image.new('RGB', (w * 2, h * 2), (24, 21, 28))
    ink = Image.fromarray(np.dstack([np.full_like(canvas, 255)] * 3 +
                                    [(canvas * 0.25).astype(np.uint8)]), 'RGBA')
    backdrop.paste(ink, (0, 0), ink)
    backdrop.save(path)


def main():
    tile, count, stats, _scale = build()
    print(f'{count} icons scattered on a {TILE[0]}x{TILE[1]} tile, '
          f'{int((tile > INK).sum()) * 100 / tile.size:.1f}% ink, '
          f'tightest gap {stats[1]:.0f}px')
    if '--check' in sys.argv:
        preview(tile, '/tmp/wallpaper_preview.png')
        print('wrote /tmp/wallpaper_preview.png (asset untouched)')
    else:
        write(tile, ASSET)
        print(f'updated {ASSET.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
