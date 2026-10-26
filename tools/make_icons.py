#!/usr/bin/env python3
"""Regenerate every platform's launcher icon from assets/images/splash_mark.png."""
import pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
BG = (0, 0, 0, 255)
INK = (255, 255, 255)

mark = Image.open(ROOT / "assets/images/splash_mark.png").convert("RGBA")
mark = mark.crop(mark.getbbox())
tint = Image.new("RGBA", mark.size, INK + (255,))
tint.putalpha(mark.split()[3])


def render(size, fill=0.56, opaque=True):
    canvas = Image.new("RGBA", (size, size), BG if opaque else (0, 0, 0, 0))
    scale = size * fill / max(tint.size)
    m = tint.resize((max(1, round(tint.width * scale)), max(1, round(tint.height * scale))), Image.LANCZOS)
    canvas.alpha_composite(m, ((size - m.width) // 2, (size - m.height) // 2))
    return canvas


for png in list(ROOT.glob("android/app/src/main/res/mipmap-*/ic_launcher.png")) + \
        list((ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset").glob("*.png")) + \
        list((ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset").glob("*.png")) + \
        list((ROOT / "web/icons").glob("Icon-*.png")) + [ROOT / "web/favicon.png"]:
    if not png.exists():
        continue
    size = Image.open(png).width
    maskable = "maskable" in png.name
    out = render(size, fill=0.42 if maskable else 0.56)
    if png.parent.name == "AppIcon.appiconset" and "ios" in png.parts:
        out = out.convert("RGB")
    out.save(png)
    print("wrote", png.relative_to(ROOT), size)


# Android adaptive icon: foreground sits inside the 66% safe zone on a black background.
res = ROOT / "android/app/src/main/res"
for density, size in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
    out = render(size, fill=0.46, opaque=False)
    out.save(res / f"mipmap-{density}" / "ic_launcher_foreground.png")
(res / "mipmap-anydpi-v26").mkdir(exist_ok=True)
(res / "mipmap-anydpi-v26" / "ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '</adaptive-icon>\n'
)
(res / "values" / "ic_launcher_background.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n    <color name="ic_launcher_background">#000000</color>\n</resources>\n'
)
