#!/usr/bin/python3
"""Draws HyprDora's logo into assets/logo: the mark, the mark with the name, and icons.

The mark is a lowercase h of rounded blocks on a dark rounded tile, in HyprDora's green; at 32 px and
below the h is one round stroke instead, which stays readable there, as on the bar. The name is set in JetBrains Mono
Bold, HyprDora's font, and turned into outlines, so it looks the same where the font is missing, as on
GitHub.

Needs fontTools and rsvg-convert, for instance unpacked from Fedora's python3-fonttools and
librsvg2-tools. The results are kept in the repository, so building the packages needs neither.

Usage: make-logo.py FONT.ttf RSVG_CONVERT OUT_DIR
"""

import os
import subprocess
import sys

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

GREEN = "#2fcf5e"
TILE = "#0b0f0d"
TEXT_ON_DARK = "#e8ece9"
TEXT_ON_LIGHT = "#0f1411"
BACKGROUND = "#0a0c0b"

# The h on a 5 by 7 grid of 9-unit blocks, one unit apart, inside a 100-unit tile.
CELLS = [
    (0, 0), (0, 1), (0, 2), (2, 2), (3, 2),
    (0, 3), (1, 3), (4, 3),
    (0, 4), (4, 4), (0, 5), (4, 5), (0, 6), (4, 6),
]  # fmt: skip


def tile(ring: bool) -> str:
    """The rounded tile, with a faint green edge on the full mark."""
    parts = [f'<rect width="100" height="100" rx="22" fill="{TILE}"/>']
    if ring:
        parts.append(
            f'<rect x="0.75" y="0.75" width="98.5" height="98.5" rx="21.5" fill="none" '
            f'stroke="{GREEN}" stroke-opacity="0.35" stroke-width="1.5"/>'
        )
    return "".join(parts)


def blocks() -> str:
    """The h of rounded blocks."""
    rects = "".join(
        f'<rect x="{27 + 10 * column}" y="{16 + 10 * row}" width="9" height="9" rx="2.2"/>'
        for column, row in CELLS
    )
    return f'<g fill="{GREEN}">{rects}</g>'


def joined() -> str:
    """The h as one round stroke, a stem and an arch, for small sizes; the bar draws the same."""
    # A 70-unit tall h, 0.62 as wide, centred on the tile; the stroke's ends sit inside that box.
    stroke, top, bottom, left, right = 13, 16, 86, 28, 72
    half = stroke / 2
    radius = (right - left - stroke) / 2
    arch = top + 70 * 0.36 + radius
    path = (
        f"M{left + half:g} {top + half:g} V{bottom - half:g} "
        f"M{left + half:g} {arch:g} A{radius:g} {radius:g} 0 0 1 {right - half:g} {arch:g} "
        f"V{bottom - half:g}"
    )
    return (
        f'<path d="{path}" fill="none" stroke="{GREEN}" stroke-width="{stroke}" '
        'stroke-linecap="round" stroke-linejoin="round"/>'
    )


def svg(width: float, height: float, body: str, label: str) -> str:
    """An SVG document."""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:g} {height:g}" '
        f'width="{width:g}" height="{height:g}" role="img" aria-label="{label}">'
        f"<title>{label}</title>{body}</svg>\n"
    )


def outlined(
    font: TTFont, text: str, size: float, x: float, baseline: float
) -> tuple[str, float]:
    """The text as outlines at a size in units, and its width."""
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    scale = size / font["head"].unitsPerEm
    paths, advance = [], 0.0
    for character in text:
        name = cmap[ord(character)]
        pen = SVGPathPen(glyphs)
        # Font units grow upwards; SVG grows downwards.
        glyphs[name].draw(
            TransformPen(pen, (scale, 0, 0, -scale, x + advance, baseline))
        )
        paths.append(pen.getCommands())
        advance += glyphs[name].width * scale
    return " ".join(paths), advance


def lockup(font: TTFont, color: str) -> str:
    """The mark and the name side by side, the name centred on the mark by its x-height."""
    size = 62
    x_height = font["OS/2"].sxHeight / font["head"].unitsPerEm * size
    baseline = 50 + x_height / 2
    path, width = outlined(font, "hyprdora", size, 124, baseline)
    body = f'<g>{tile(ring=True)}{blocks()}</g><path d="{path}" fill="{color}"/>'
    return svg(124 + width, 100, body, "HyprDora")


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    font_path, rsvg, out = sys.argv[1:]
    font = TTFont(font_path)
    os.makedirs(os.path.join(out, "icons"), exist_ok=True)

    files = {
        "hyprdora-mark.svg": svg(100, 100, tile(ring=True) + blocks(), "HyprDora"),
        "hyprdora-mark-small.svg": svg(
            100, 100, tile(ring=False) + joined(), "HyprDora"
        ),
        "hyprdora-logo.svg": lockup(font, TEXT_ON_DARK),
        "hyprdora-logo-light.svg": lockup(font, TEXT_ON_LIGHT),
    }
    # The repository's preview on GitHub: 1280 by 640, the logo centred on HyprDora's black.
    with_name = lockup(font, TEXT_ON_DARK)
    inner = with_name[with_name.index("<title>") :].removesuffix("</svg>\n")
    width = float(with_name.split('viewBox="0 0 ')[1].split(" ")[0])
    scale = 760 / width
    files["hyprdora-social.svg"] = svg(
        1280,
        640,
        f'<rect width="1280" height="640" fill="{BACKGROUND}"/>'
        f'<g transform="translate({(1280 - width * scale) / 2:.1f} {(640 - 100 * scale) / 2:.1f}) '
        f'scale({scale:.4f})">{inner}</g>',
        "HyprDora",
    )
    for name, text in files.items():
        with open(os.path.join(out, name), "w", encoding="utf-8") as file:
            file.write(text)

    def render(source: str, target: str, width: int, height: int) -> None:
        subprocess.run(
            [
                rsvg,
                "-w",
                str(width),
                "-h",
                str(height),
                "-o",
                target,
                os.path.join(out, source),
            ],
            check=True,
        )

    for size in (16, 22, 24, 32, 48, 64, 128, 256, 512):
        source = "hyprdora-mark-small.svg" if size <= 32 else "hyprdora-mark.svg"
        render(source, os.path.join(out, "icons", f"hyprdora-{size}.png"), size, size)
    render("hyprdora-social.svg", os.path.join(out, "hyprdora-social.png"), 1280, 640)
    return 0


if __name__ == "__main__":
    sys.exit(main())
