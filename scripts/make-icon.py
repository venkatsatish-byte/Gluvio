"""Draws the Gluvio app icon (1024x1024, opaque RGB as the App Store requires).

    python3 -m pip install pillow
    python3 scripts/make-icon.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4  # draw large, then downsample for smooth edges
S = SIZE * SCALE

top, bottom = (14, 116, 144), (34, 170, 110)  # teal to green
img = Image.new("RGB", (S, S))
draw = ImageDraw.Draw(img)
for y in range(S):
    t = y / (S - 1)
    draw.line([(0, y), (S, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))

# Glucose drop: a circle with a pointed top.
cx, cy, r = S / 2, S * 0.60, S * 0.25
tip = (cx, S * 0.16)
angle = math.asin(r / (cy - tip[1]))
left = (cx - r * math.cos(angle), cy - r * math.sin(angle))
right = (cx + r * math.cos(angle), cy - r * math.sin(angle))
draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill="white")
draw.polygon([tip, left, right], fill="white")

# A steady trend line inside the drop.
w = S * 0.025
points = [(cx - r * 0.62, cy + r * 0.10), (cx - r * 0.22, cy + r * 0.10), (cx - r * 0.02, cy - r * 0.38),
          (cx + r * 0.20, cy + r * 0.40), (cx + r * 0.36, cy + r * 0.10), (cx + r * 0.62, cy + r * 0.10)]
draw.line(points, fill=(18, 132, 132), width=round(w), joint="curve")
for x, y in (points[0], points[-1]):
    draw.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=(18, 132, 132))

icon = img.resize((SIZE, SIZE), Image.LANCZOS)
root = Path(__file__).resolve().parent.parent
for folder in ("App/Assets.xcassets/AppIcon.appiconset", "Watch/Assets.xcassets/AppIcon.appiconset"):
    out = root / folder / "AppIcon.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    icon.save(out, optimize=True)
    print("wrote", out.relative_to(root))
