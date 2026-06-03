#!/usr/bin/env python3
"""Generate the 1024x1024 AppIcon PNG for Locals.

Mustard ground with cream serif italic "L" - matches the locals-web
editorial aesthetic (Spectral italic on warm cream). Run once; checked in
to the asset catalog. Replace whenever brand changes.
"""

from PIL import Image, ImageDraw, ImageFont
import os

OUT = "D:/.code/locals-ios/Sources/Locals/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
SIZE = 1024

# Locals palette
MUSTARD = (196, 154, 63)  # #C49A3F
CREAM = (232, 223, 201)  # #E8DFC9
INK = (31, 24, 16)  # #1F1810

img = Image.new("RGB", (SIZE, SIZE), MUSTARD)
draw = ImageDraw.Draw(img)

# Find a serif italic font. macOS-installed Spectral if present, otherwise
# Times New Roman Italic on Windows, otherwise PIL's bundled DejaVu Serif
# Italic. The aesthetic target is one editorial italic "L" - close enough
# matters more than exact face for an app icon.
font_candidates = [
    ("C:/Windows/Fonts/timesi.ttf", 820),
    ("/Library/Fonts/Times New Roman Italic.ttf", 820),
    ("C:/Windows/Fonts/georgiai.ttf", 820),
    ("/System/Library/Fonts/Supplemental/Georgia Italic.ttf", 820),
]
font = None
for path, size in font_candidates:
    if os.path.exists(path):
        font = ImageFont.truetype(path, size)
        break

if font is None:
    # PIL default - not pretty but renders without a system font.
    font = ImageFont.load_default()

text = "L"
bbox = draw.textbbox((0, 0), text, font=font)
w = bbox[2] - bbox[0]
h = bbox[3] - bbox[1]
# Center optically (raise the visual centre by 6% to compensate for italic
# tilt + the serif tail that pulls the bbox down).
x = (SIZE - w) // 2 - bbox[0]
y = (SIZE - h) // 2 - bbox[1] - int(SIZE * 0.04)
draw.text((x, y), text, fill=CREAM, font=font)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT, "PNG", optimize=True)
print(f"wrote {OUT}  {os.path.getsize(OUT)} bytes")
