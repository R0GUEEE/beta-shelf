#!/usr/bin/env python3
"""Render the 1024pt Beta Shelf app icon (dark gradient + glass flask)."""
from PIL import Image, ImageDraw, ImageFilter
import math

S = 1024
img = Image.new("RGB", (S, S), (10, 12, 26))
px = img.load()

# Diagonal gradient: deep navy -> indigo -> violet
c0 = (8, 14, 34)
c1 = (44, 34, 120)
c2 = (86, 46, 168)
for y in range(S):
    for x in range(0, S, 4):
        t = (x / S) * 0.55 + (y / S) * 0.45
        if t < 0.5:
            k = t / 0.5
            col = tuple(int(c0[i] + (c1[i] - c0[i]) * k) for i in range(3))
        else:
            k = (t - 0.5) / 0.5
            col = tuple(int(c1[i] + (c2[i] - c1[i]) * k) for i in range(3))
        for dx in range(4):
            if x + dx < S:
                px[x + dx, y] = col

# Soft blue glow behind the flask
glow = Image.new("RGB", (S, S), (0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse((230, 250, 800, 820), fill=(40, 120, 255))
glow = glow.filter(ImageFilter.GaussianBlur(150))
img = Image.blend(img, Image.composite(glow, img, glow.convert("L")), 0.45)
d = ImageDraw.Draw(img, "RGBA")

# Shelf line
d.rounded_rectangle((150, 792, 874, 812), radius=10, fill=(255, 255, 255, 38))

# Flask body: neck + conical body
cx = S // 2
neck_w = 96
d.rounded_rectangle((cx - neck_w // 2, 268, cx + neck_w // 2, 430), radius=16,
                    fill=(255, 255, 255, 46), outline=(255, 255, 255, 210), width=9)
# rim
d.rounded_rectangle((cx - neck_w // 2 - 22, 244, cx + neck_w // 2 + 22, 286), radius=20,
                    fill=(255, 255, 255, 70), outline=(255, 255, 255, 235), width=9)
# body
body = [
    (cx - neck_w // 2, 430),
    (cx - 268, 704),
    (cx - 232, 760),
    (cx + 232, 760),
    (cx + 268, 704),
    (cx + neck_w // 2, 430),
]
d.polygon(body, fill=(255, 255, 255, 40), outline=(255, 255, 255, 215))
d.line(body + [body[0]], fill=(255, 255, 255, 225), width=9, joint="curve")

# Liquid inside the flask
liquid_top = 610
liquid = [
    (cx - 196, liquid_top),
    (cx - 232, 760),
    (cx + 232, 760),
    (cx + 196, liquid_top),
]
d.polygon(liquid, fill=(64, 196, 255, 190))
d.line([(cx - 196, liquid_top), (cx + 196, liquid_top)], fill=(160, 232, 255, 220), width=8)

# Bubbles in the liquid
for bx, by, r in [(cx - 110, 690, 17), (cx - 40, 650, 11), (cx + 40, 706, 21),
                  (cx + 116, 664, 13), (cx - 150, 726, 9), (cx + 162, 720, 8)]:
    d.ellipse((bx - r, by - r, bx + r, by + r), fill=(235, 250, 255, 210))

# Vapour highlights
for hx, hy, rr in [(cx - 60, 214, 9), (cx + 10, 190, 6), (cx + 70, 222, 7)]:
    d.ellipse((hx - rr, hy - rr, hx + rr, hy + rr), fill=(255, 255, 255, 120))

# Top-left sheen
sheen = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(sheen)
sd.ellipse((-260, -420, 700, 460), fill=(255, 255, 255, 26))
img = Image.alpha_composite(img.convert("RGBA"), sheen).convert("RGB")

img.save("Sources/BetaShelf/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png", optimize=True)
img.resize((256, 256), Image.LANCZOS).save("/tmp/icon_preview.png")
print("ok")
