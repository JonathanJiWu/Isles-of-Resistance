#!/usr/bin/env python3
"""Regenerate the Windows icon and installer artwork from the project icon.

    python3 installer/windows/make_assets.py /path/to/godot

Godot renders icon.svg at every icon size (so small sizes stay crisp), then
Pillow assembles icon.ico and draws the NSIS welcome and header bitmaps.
The outputs are committed, so this only needs to run when the art changes.
"""
import math
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
FONT = os.path.join(ROOT, "Assets", "fonts", "ChakraPetch-Bold.ttf")
FONT_SEMI = os.path.join(ROOT, "Assets", "fonts", "ChakraPetch-SemiBold.ttf")
ICON_SIZES = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]

NAVY_TOP = (5, 12, 24)
NAVY_BOTTOM = (11, 27, 44)
CYAN = (79, 209, 197)
PINK = (255, 143, 199)

RENDER_SCRIPT = """extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var svg := FileAccess.get_file_as_string(args[0])
	for s in args.slice(2):
		var img := Image.new()
		img.load_svg_from_string(svg, float(s) / 128.0)
		img.save_png(args[1].path_join("icon_%s.png" % s))
	quit()
"""


def render_icons(godot, out_dir, sizes):
    script = os.path.join(out_dir, "render_icon.gd")
    with open(script, "w") as f:
        f.write(RENDER_SCRIPT)
    subprocess.run(
        [godot, "--headless", "-s", script, "--",
         os.path.join(ROOT, "icon.svg"), out_dir] + [str(s) for s in sizes],
        check=True, cwd=out_dir, stdout=subprocess.DEVNULL)
    return {s: Image.open(os.path.join(out_dir, "icon_%d.png" % s)).convert("RGBA") for s in sizes}


def background(w, h):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(NAVY_TOP[i] + (NAVY_BOTTOM[i] - NAVY_TOP[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c + (255,)
    # faint hex grid
    grid = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(grid)
    r = 14.0
    dx, dy = math.sqrt(3) * r, 1.5 * r
    for row in range(-1, int(h / dy) + 2):
        for col in range(-1, int(w / dx) + 2):
            cx = col * dx + (dx / 2 if row % 2 else 0)
            cy = row * dy
            pts = [(cx + r * math.cos(math.radians(60 * k + 30)),
                    cy + r * math.sin(math.radians(60 * k + 30))) for k in range(7)]
            d.line(pts, fill=CYAN + (22,), width=1)
    return Image.alpha_composite(img, grid)


def glow_text(img, xy, text, font, fill, glow, anchor="mm", spacing=0):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if spacing:
        draw_spaced(d, xy, text, font, glow + (200,), spacing)
    else:
        d.text(xy, text, font=font, fill=glow + (200,), anchor=anchor)
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(3)))
    d = ImageDraw.Draw(img)
    if spacing:
        draw_spaced(d, xy, text, font, fill, spacing)
    else:
        d.text(xy, text, font=font, fill=fill, anchor=anchor)


def draw_spaced(d, xy, text, font, fill, spacing):
    widths = [font.getlength(ch) for ch in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x = xy[0] - total / 2
    for ch, w in zip(text, widths):
        d.text((x, xy[1]), ch, font=font, fill=fill, anchor="lm")
        x += w + spacing


def neon_line(img, y, x0, x1):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    mid = (x0 + x1) / 2
    d.line([(x0, y), (mid, y)], fill=CYAN + (255,), width=2)
    d.line([(mid, y), (x1, y)], fill=PINK + (255,), width=2)
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(2.5)))
    img.alpha_composite(layer)


def welcome(icons):
    w, h = 164, 314
    img = background(w, h)
    halo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse((22, 22, 142, 142), fill=CYAN + (60,))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(18)))
    icon = icons[96]
    img.alpha_composite(icon, ((w - icon.width) // 2, 34))
    title = ImageFont.truetype(FONT, 21)
    glow_text(img, (w / 2, 160), "ISLES OF", title, (240, 246, 252, 255), CYAN)
    glow_text(img, (w / 2, 184), "RESISTANCE", title, (240, 246, 252, 255), CYAN)
    neon_line(img, 204, 26, w - 26)
    kicker = ImageFont.truetype(FONT_SEMI, 9)
    glow_text(img, (w / 2, 220), "THE LANTERN STRAIT", kicker, PINK + (255,), PINK, spacing=1.5)
    small = ImageFont.truetype(FONT_SEMI, 9)
    d = ImageDraw.Draw(img)
    for i, line in enumerate(["A turn-based", "air defense campaign"]):
        d.text((w / 2, 268 + i * 12), line, font=small, fill=(150, 175, 200, 255), anchor="mm")
    return img.convert("RGB")


def header(icons):
    w, h = 150, 57
    img = background(w, h)
    icon = icons[40]
    img.alpha_composite(icon, (8, (h - icon.height) // 2))
    f = ImageFont.truetype(FONT, 13)
    glow_text(img, (54, 22), "ISLES OF", f, (240, 246, 252, 255), CYAN, anchor="lm")
    glow_text(img, (54, 37), "RESISTANCE", f, (240, 246, 252, 255), CYAN, anchor="lm")
    return img.convert("RGB")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    with tempfile.TemporaryDirectory() as tmp:
        icons = render_icons(os.path.abspath(sys.argv[1]), tmp, ICON_SIZES)
        big = icons[256]
        big.save(os.path.join(HERE, "icon.ico"), format="ICO",
                 sizes=[(s, s) for s in ICON_SIZES],
                 append_images=[icons[s] for s in ICON_SIZES if s != 256])
        welcome(icons).save(os.path.join(HERE, "welcome.bmp"))
        header(icons).save(os.path.join(HERE, "header.bmp"))
    print("wrote icon.ico, welcome.bmp, header.bmp to", HERE)


if __name__ == "__main__":
    main()
