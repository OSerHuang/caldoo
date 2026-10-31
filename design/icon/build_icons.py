#!/usr/bin/env python3
"""Build the app icon set from the SVG design sources.

Renders `icon_bowl.svg` (primary), `icon_plate.svg` and `icon_hao.svg`
(alternates) via macOS QuickLook (qlmanage), post-processes with Pillow, and
writes:
  * design/icon/preview_<name>.png        512 px previews
  * design/icon/preview_sheet.png         side-by-side contact sheet
  * design/icon/playstore_512.png         Play Store listing icon (square)
  * android .../mipmap-*/ic_launcher.png            48/72/96/144/192
  * android .../mipmap-*/ic_launcher_round.png      48/72/96/144/192
  * android .../mipmap-*/ic_launcher_foreground.png 108/162/216/324/432
  * android .../mipmap-anydpi-v26/ic_launcher*.xml   adaptive icon wiring
  * android .../values/colors.xml                    adaptive background

Run:  .venv/bin/python3 design/icon/build_icons.py
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "design" / "icon"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
TMP = OUT / "_tmp"

MASTER = 1024

# ---------------------------------------------------------------- SVG sources

BG_DEFS = """<defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#F7F8F3"/>
      <stop offset="1" stop-color="#E7EBDD"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.30" r="0.80">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
  </defs>"""

BOWL_ART = """  <!-- floating grains -->
  <circle cx="352" cy="336" r="9" fill="#D6E0C9"/>
  <circle cx="686" cy="282" r="7" fill="#D6E0C9"/>
  <!-- steam -->
  <g fill="none" stroke="#C5D3BB" stroke-width="22" stroke-linecap="round" opacity="0.95">
    <path d="M 446 470 C 420 426 466 394 444 346 C 432 320 436 296 452 274"/>
    <path d="M 512 452 C 484 406 532 372 506 322 C 492 294 497 268 514 244"/>
    <path d="M 578 470 C 552 426 598 394 576 346 C 564 320 568 296 584 274"/>
  </g>
  <!-- bowl -->
  <rect x="442" y="700" width="140" height="30" rx="15" fill="#A9BCA0"/>
  <ellipse cx="512" cy="498" rx="222" ry="40" fill="#E9EFDF"/>
  <path d="M 290 498 A 222 40 0 0 1 734 498 C 718 624 624 712 512 712 C 400 712 306 624 290 498 Z" fill="#B6C7AD"/>
  <!-- leaf garnish -->
  <path d="M 664 462 C 672 424 702 402 740 404 C 740 442 712 466 676 464 C 672 462 668 461 664 462 Z" fill="#9EB995"/>
  <path d="M 674 456 C 694 444 716 428 732 412" fill="none" stroke="#7E9778" stroke-width="5" stroke-linecap="round"/>"""

PLATE_DEFS = """<defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#F1F4EB"/>
      <stop offset="1" stop-color="#E2E8D7"/>
    </linearGradient>
  </defs>"""

PLATE_ART = """  <circle cx="330" cy="300" r="8" fill="#D6E0C9"/>
  <circle cx="706" cy="664" r="7" fill="#D6E0C9"/>
  <circle cx="512" cy="512" r="296" fill="#FCFDFB"/>
  <circle cx="512" cy="512" r="212" fill="#F2F5EC" stroke="#E3EAD9" stroke-width="6"/>
  <!-- two-leaf sprout -->
  <path d="M 506 610 C 500 578 490 550 472 528" fill="none" stroke="#9DB894" stroke-width="13" stroke-linecap="round"/>
  <path d="M 518 610 C 526 576 540 550 560 530" fill="none" stroke="#9DB894" stroke-width="13" stroke-linecap="round"/>
  <path d="M 470 528 C 438 490 388 478 346 496 C 358 544 406 568 454 552 C 460 546 466 537 470 528 Z" fill="#9DB894"/>
  <path d="M 562 528 C 582 478 628 452 676 462 C 668 514 624 544 576 538 C 571 535 566 532 562 528 Z" fill="#B7C8AD"/>"""


def hao_svg() -> str:
    """The 「好」 mark: MiSans-Bold glyph outline as a pure SVG path."""
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.ttLib import TTFont

    font = TTFont(ROOT / "assets" / "fonts" / "MiSans-Bold.ttf")
    cmap = font.getBestCmap()
    glyph_set = font.getGlyphSet()
    glyph_name = cmap[ord("好")]
    pen = SVGPathPen(glyph_set)
    glyph_set[glyph_name].draw(pen)
    path = pen.getCommands()

    upm = font["head"].unitsPerEm
    target_height = 540.0
    # CJK glyphs sit roughly between -0.12 and 0.88 of the em square.
    s = target_height / (upm * 0.94)
    w = upm * s
    # Center horizontally; optically center the em box vertically.
    tx = (MASTER - w) / 2 - 60 * s
    ty = (MASTER + target_height) / 2 + 100 * s
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {MASTER} {MASTER}">
  {PLATE_DEFS}
  <rect width="{MASTER}" height="{MASTER}" rx="232" fill="url(#bg)"/>
  <circle cx="368" cy="292" r="8" fill="#D6E0C9"/>
  <circle cx="676" cy="726" r="7" fill="#D6E0C9"/>
  <g transform="translate({tx:.1f},{ty:.1f}) scale({s:.4f},{-s:.4f})">
    <path d="{path}" fill="#A3BC9A"/>
  </g>
</svg>
"""


def wrap(defs: str, art: str, *, rx: int = 232, art_transform: str = "") -> str:
    g_open = f'<g id="art"{art_transform}>' if art_transform else '<g id="art">'
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {MASTER} {MASTER}">
  {defs}
  <rect width="{MASTER}" height="{MASTER}" rx="{rx}" fill="url(#bg)"/>
  <rect width="{MASTER}" height="{MASTER}" rx="{rx}" fill="url(#glow)"/>
  {g_open}
{art}
  </g>
</svg>
"""


def render_via_qlmanage(svg_path: Path, out_png: Path, size: int = MASTER) -> None:
    subprocess.run(
        ["qlmanage", "-t", "-s", str(size), "-o", str(svg_path.parent), str(svg_path)],
        check=True,
        capture_output=True,
    )
    produced = svg_path.with_suffix(".svg.png")
    produced.replace(out_png)


def save_scaled(master: Image.Image, path: Path, size: int) -> None:
    master.resize((size, size), Image.LANCZOS).save(path)


def rounded_master(art_svg: str, defs: str) -> Image.Image:
    svg = wrap(defs, art_svg)
    src = TMP / "legacy.svg"
    src.write_text(svg)
    dst = TMP / "legacy.png"
    render_via_qlmanage(src, dst)
    return Image.open(dst).convert("RGBA")


def write_android(legacy: Image.Image) -> None:
    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for dpi, size in densities.items():
        d = RES / f"mipmap-{dpi}"
        d.mkdir(parents=True, exist_ok=True)
        save_scaled(legacy, d / "ic_launcher.png", size)
        # Round: circular mask over the full-bleed art.
        mask = Image.new("L", (MASTER, MASTER), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, MASTER, MASTER), fill=255)
        round_img = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
        round_img.paste(legacy, (0, 0), mask)
        save_scaled(round_img, d / "ic_launcher_round.png", size)

    # Adaptive icon (API 26+): vector foreground over a flat background —
    # resolution independent, and the art sits inside the 66/108 safe zone
    # via the outer group transform.
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    adaptive = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
"""
    (anydpi / "ic_launcher.xml").write_text(adaptive)
    (anydpi / "ic_launcher_round.xml").write_text(adaptive)

    drawable = RES / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    (drawable / "ic_launcher_foreground.xml").write_text(FOREGROUND_XML)

    values = RES / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "colors.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#F0F3E9</color>
</resources>
"""
    )


# The BOWL_ART paths translated to VectorDrawable pathData (same grammar),
# wrapped in a group that scales the art into the adaptive safe zone.
FOREGROUND_XML = """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="1024"
    android:viewportHeight="1024">
  <group
      android:translateX="174"
      android:translateY="174"
      android:scaleX="0.66"
      android:scaleY="0.66">
    <path android:fillColor="#D6E0C9" android:pathData="M343,336 a9,9 0 0,1 18,0 a9,9 0 0,1 -18,0 Z"/>
    <path android:fillColor="#D6E0C9" android:pathData="M679,282 a7,7 0 0,1 14,0 a7,7 0 0,1 -14,0 Z"/>
    <path android:strokeColor="#C5D3BB" android:strokeWidth="22" android:strokeLineCap="round" android:pathData="M446,470 C420,426 466,394 444,346 C432,320 436,296 452,274"/>
    <path android:strokeColor="#C5D3BB" android:strokeWidth="22" android:strokeLineCap="round" android:pathData="M512,452 C484,406 532,372 506,322 C492,294 497,268 514,244"/>
    <path android:strokeColor="#C5D3BB" android:strokeWidth="22" android:strokeLineCap="round" android:pathData="M578,470 C552,426 598,394 576,346 C564,320 568,296 584,274"/>
    <path android:fillColor="#A9BCA0" android:pathData="M457,700 L567,700 A15,15 0 0,1 582,715 A15,15 0 0,1 567,730 L457,730 A15,15 0 0,1 442,715 A15,15 0 0,1 457,700 Z"/>
    <path android:fillColor="#E9EFDF" android:pathData="M290,498 A222,40 0 0,1 734,498 A222,40 0 0,1 290,498 Z"/>
    <path android:fillColor="#B6C7AD" android:pathData="M290,498 A222,40 0 0,1 734,498 C718,624 624,712 512,712 C400,712 306,624 290,498 Z"/>
    <path android:fillColor="#9EB995" android:pathData="M664,462 C672,424 702,402 740,404 C740,442 712,466 676,464 C672,462 668,461 664,462 Z"/>
    <path android:strokeColor="#7E9778" android:strokeWidth="5" android:strokeLineCap="round" android:pathData="M674,456 C694,444 716,428 732,412"/>
  </group>
</vector>
"""


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    TMP.mkdir(parents=True, exist_ok=True)

    bowl_svg = wrap(BG_DEFS, BOWL_ART)
    plate_svg = wrap(PLATE_DEFS, PLATE_ART)
    hao = hao_svg()

    (OUT / "icon_bowl.svg").write_text(bowl_svg)
    (OUT / "icon_plate.svg").write_text(plate_svg)
    (OUT / "icon_hao.svg").write_text(hao)

    # --- masters ------------------------------------------------------------
    (TMP / "bowl.svg").write_text(bowl_svg)
    render_via_qlmanage(TMP / "bowl.svg", TMP / "bowl.png")
    (TMP / "plate.svg").write_text(plate_svg)
    render_via_qlmanage(TMP / "plate.svg", TMP / "plate.png")
    (TMP / "hao.svg").write_text(hao)
    render_via_qlmanage(TMP / "hao.svg", TMP / "hao.png")

    bowl = Image.open(TMP / "bowl.png").convert("RGBA")
    plate = Image.open(TMP / "plate.png").convert("RGBA")
    hao_img = Image.open(TMP / "hao.png").convert("RGBA")

    # --- previews -----------------------------------------------------------
    for name, img in [("bowl", bowl), ("plate", plate), ("hao", hao_img)]:
        save_scaled(img, OUT / f"preview_{name}.png", 512)

    sheet = Image.new("RGBA", (512 * 3 + 40 * 4, 512 + 80), (255, 255, 255, 255))
    for i, img in enumerate([bowl, plate, hao_img]):
        sheet.paste(img.resize((512, 512), Image.LANCZOS), (40 + i * (512 + 40), 40))
    sheet.convert("RGB").save(OUT / "preview_sheet.png")

    # --- play store (full square, no corner radius) --------------------------
    square_svg = bowl_svg.replace('rx="232"', 'rx="0"')
    (TMP / "square.svg").write_text(square_svg)
    render_via_qlmanage(TMP / "square.svg", TMP / "square.png")
    square = Image.open(TMP / "square.png").convert("RGBA")
    save_scaled(square, OUT / "playstore_512.png", 512)

    # --- android res ---------------------------------------------------------
    write_android(bowl)

    print("done:", OUT)


if __name__ == "__main__":
    main()
