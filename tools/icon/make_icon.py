#!/usr/bin/env python3
"""Dessine l'icône d'Oathfall : une épée plantée dans la terre devant la lune,
en papier découpé, nuit bleue et or pâle. Sortie dans assets/icon/.

    python3 -I tools/icon/make_icon.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "icon")
S = 2048  # dessin en grand, réduit ensuite
NIGHT_TOP, NIGHT_BOT = (8, 11, 30), (26, 34, 70)
MOON, EMBER, INK = (232, 222, 190), (214, 150, 70), (4, 5, 12)


def background():
    img = Image.new("RGB", (S, S))
    px = ImageDraw.Draw(img)
    for y in range(S):
        t = y / S
        px.line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(NIGHT_TOP, NIGHT_BOT)))
    return img


def subject(with_moon=True):
    """Lune, crête, épée plantée : sur fond transparent."""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = S // 2
    if with_moon:
        glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        g = ImageDraw.Draw(glow)
        g.ellipse([cx - 560, 520 - 560, cx + 560, 520 + 560], fill=MOON + (70,))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(90)))
        d.ellipse([cx - 380, 520 - 380, cx + 380, 520 + 380], fill=MOON + (255,))
    # terre : crête irrégulière
    d.polygon([(0, 1500), (260, 1450), (520, 1510), (800, 1440), (1100, 1500), (1400, 1450),
               (1700, 1520), (S, 1470), (S, S), (0, S)], fill=INK + (255,))
    # épée plantée, pointe en bas, garde large
    blade_top, blade_bot = 640, 1560
    d.polygon([(cx - 70, blade_top + 120), (cx, blade_top), (cx + 70, blade_top + 120),
               (cx + 70, blade_bot - 120), (cx, blade_bot), (cx - 70, blade_bot - 120)], fill=INK + (255,))
    d.rectangle([cx - 330, 1000, cx + 330, 1070], fill=INK + (255,))      # garde
    d.polygon([(cx - 330, 1000), (cx - 380, 960), (cx - 330, 1070)], fill=INK + (255,))
    d.polygon([(cx + 330, 1000), (cx + 380, 960), (cx + 330, 1070)], fill=INK + (255,))
    d.rectangle([cx - 42, 1070, cx + 42, 1240], fill=INK + (255,))
    d.ellipse([cx - 78, 560 - 0, cx + 78, 716], fill=INK + (255,))
    # braises
    for x, y, r in [(cx - 520, 1280, 16), (cx + 470, 1180, 12), (cx - 300, 1100, 10), (cx + 640, 1360, 14), (cx + 190, 1330, 9)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=EMBER + (255,))
    return img


def save(img, name, size):
    os.makedirs(OUT, exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name))


bg = background()
full = bg.convert("RGBA")
full.alpha_composite(subject())
save(full, "icon.png", 512)
save(full, "main_192.png", 192)
save(bg, "adaptive_bg_432.png", 432)
# Premier plan adaptatif : le sujet, réduit pour tenir dans la zone sûre (66 %).
fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
small = subject().resize((int(S * 0.66), int(S * 0.66)), Image.LANCZOS)
fg.alpha_composite(small, ((S - small.width) // 2, (S - small.height) // 2))
save(fg, "adaptive_fg_432.png", 432)
print("icônes écrites dans", os.path.abspath(OUT))
