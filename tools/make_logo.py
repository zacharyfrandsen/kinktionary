"""Tints the Aftercare mark with the app's pink and writes the copies it is used in.

The supplied artwork (`data_source/aftercare_logo.png`) is the mark in white on
transparent. Everything else is generated from it, so the logo changes in one
place:

  assets/images/aftercare_logo.png   the loading screen's mark, transparent
  landing/assets/aftercare.png       the website's brand slot and footer
  landing/assets/favicon.png         the site's tab icon, on the app background
  landing/assets/touch-icon.png      the same, at the size iOS asks for
  web/favicon.png                    the app's own tab icon

The pink is AppPalette.rose from lib/theme.dart; keep the two in step.

    python3 tools/make_logo.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'data_source/aftercare_logo.png'
APP_MARK = ROOT / 'assets/images/aftercare_logo.png'
SITE_MARK = ROOT / 'landing/assets/aftercare.png'
FAVICON = ROOT / 'web/favicon.png'
SITE_FAVICON = ROOT / 'landing/assets/favicon.png'
TOUCH_ICON = ROOT / 'landing/assets/touch-icon.png'

PINK = (0xF6, 0xC9, 0xE6)      # AppPalette.rose
BACKGROUND = (0x0F, 0x0D, 0x13)  # AppPalette.background


def tinted(alpha, size):
    """The mark in pink, cropped to its ink with a little air around it."""
    w, h = alpha.size
    ink = alpha.point(lambda a: a)
    box = ink.getbbox()
    if box:
        pad = int(0.04 * max(box[2] - box[0], box[3] - box[1]))
        box = (max(0, box[0] - pad), max(0, box[1] - pad),
               min(w, box[2] + pad), min(h, box[3] + pad))
        ink = ink.crop(box)
    scale = size / max(ink.size)
    ink = ink.resize((max(1, round(ink.width * scale)),
                      max(1, round(ink.height * scale))), Image.LANCZOS)
    out = Image.new('RGBA', ink.size, PINK + (0,))
    out.putalpha(ink)
    return out


def plate(path, alpha, side):
    """The mark on the app's dark plate: a tab icon is drawn at 16px, where a
    mark on a transparent background disappears."""
    icon = Image.new('RGBA', (side, side), BACKGROUND + (255,))
    ImageDraw.Draw(icon).rounded_rectangle(
        (0, 0, side - 1, side - 1),
        radius=round(side * 0.22),
        fill=BACKGROUND + (255,))
    glyph = tinted(alpha, round(side * 0.69))
    icon.alpha_composite(glyph, ((side - glyph.width) // 2,
                                 (side - glyph.height) // 2))
    icon.save(path, optimize=True)


def main():
    src = Image.open(SOURCE).convert('RGBA')
    alpha = src.getchannel('A')

    mark = tinted(alpha, 512)
    mark.save(APP_MARK, optimize=True)
    print(f'{APP_MARK.relative_to(ROOT)} {mark.size[0]}x{mark.size[1]}')

    site = tinted(alpha, 128)
    site.save(SITE_MARK, optimize=True)
    print(f'{SITE_MARK.relative_to(ROOT)} {site.size[0]}x{site.size[1]}')

    for path, side in ((FAVICON, 64), (SITE_FAVICON, 64), (TOUCH_ICON, 180)):
        plate(path, alpha, side)
        print(f'{path.relative_to(ROOT)} {side}x{side}')


if __name__ == '__main__':
    main()
