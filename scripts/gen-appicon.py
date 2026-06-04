#!/usr/bin/env python3
"""
Generate the Locals AppIcon at 1024x1024.

Mark: a small cluster of circles in cream + ink on a mustard ground.
The cluster echoes the map-clustering mechanic (the count-circle that
appears when several merchants overlap) and reads, at app-icon scale,
as "people near you" without spelling it out.

Composition:
  - mustard #C49A3F background, full bleed, soft inner halo
  - three circles in a triangular arrangement
  - top circle = ink (the user / anchor)
  - bottom-left + bottom-right = cream (the locals)
  - sizes graduate so the eye reads the ink dot first
  - circles tangent, not overlapping - keeps the silhouette clean
"""

import math
import os
from PIL import Image, ImageDraw

SIZE = 1024
OUT = os.path.join(
    os.path.dirname(__file__),
    "..",
    "Sources",
    "Locals",
    "Resources",
    "Assets.xcassets",
    "AppIcon.appiconset",
    "AppIcon-1024.png",
)

MUSTARD = (196, 154, 63, 255)  # #C49A3F
MUSTARD_DEEP = (158, 121, 36, 255)  # #9E7924 - inner halo
CREAM = (232, 223, 201, 255)  # #E8DFC9
INK = (31, 24, 16, 255)  # #1F1810


def paste_circle(canvas, cx, cy, r, fill):
    """Draw a circle anti-aliased onto canvas at (cx, cy) radius r."""
    box = (cx - r, cy - r, cx + r, cy + r)
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.ellipse(box, fill=fill)
    canvas.alpha_composite(overlay)


def main():
    img = Image.new("RGBA", (SIZE, SIZE), MUSTARD)

    # Soft deeper-mustard halo from the bottom so the canvas doesn't read
    # as a flat swatch at icon sizes.
    halo = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    halo_draw = ImageDraw.Draw(halo)
    halo_draw.ellipse(
        (-SIZE * 0.15, SIZE * 0.55, SIZE * 1.15, SIZE * 1.85),
        fill=(MUSTARD_DEEP[0], MUSTARD_DEEP[1], MUSTARD_DEEP[2], 60),
    )
    img.alpha_composite(halo)

    cx, cy = SIZE / 2, SIZE / 2
    big_r = SIZE * 0.18
    small_r = SIZE * 0.13

    ink_cx = cx
    ink_cy = cy - SIZE * 0.10

    angle = math.radians(60)
    gap = big_r + small_r + SIZE * 0.005
    left_cx = ink_cx - gap * math.sin(angle)
    left_cy = ink_cy + gap * math.cos(angle)
    right_cx = ink_cx + gap * math.sin(angle)
    right_cy = ink_cy + gap * math.cos(angle)

    # Cream pair first (sits behind), then ink on top so the tangent
    # points read crisp.
    paste_circle(img, left_cx, left_cy, small_r, CREAM)
    paste_circle(img, right_cx, right_cy, small_r, CREAM)

    # Soft cast shadow beneath the ink anchor before painting the ink
    # circle - sells the cluster as objects on a ground.
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse(
        (
            ink_cx - big_r * 0.9,
            ink_cy + big_r * 0.55,
            ink_cx + big_r * 0.9,
            ink_cy + big_r * 0.85,
        ),
        fill=(0, 0, 0, 35),
    )
    img.alpha_composite(shadow)

    paste_circle(img, ink_cx, ink_cy, big_r, INK)

    img.convert("RGB").save(OUT, "PNG", optimize=True)
    print(f"wrote {os.path.normpath(OUT)}  {os.path.getsize(OUT)} bytes")


if __name__ == "__main__":
    main()
