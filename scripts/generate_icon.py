#!/usr/bin/env python3
"""
Generate the Garage Time AppIcon master (1024x1024 PNG, NO alpha).

Design: a clock face with a stylized wrench as the hour hand.
- Dark background with subtle radial vignette
- Cream clock face with 12 tick marks (4 long, 8 short)
- Thin gray minute hand pointing up-left (~11 o'clock)
- Bold amber wrench acting as the hour hand, pointing down-right (~4 o'clock)
- Center hub disc with a tiny amber dot

Apple's icon mask rounds the corners automatically; output is RGB (no alpha).
"""
from __future__ import annotations
import math
import pathlib
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SIZE = 1024
OUT_DIR = pathlib.Path(__file__).resolve().parent.parent / "GarageTime" / "Assets.xcassets" / "AppIcon.appiconset"
OUT_PATH = OUT_DIR / "icon-1024.png"

# Brand palette
BG_OUTER       = (10, 10, 12)
BG_INNER       = (34, 32, 38)
FACE           = (244, 240, 228)
FACE_EDGE      = (210, 200, 180)
FACE_DEEP      = (170, 158, 138)
TICK_MAJOR     = (40, 32, 28)
TICK_MINOR     = (110, 100, 90)
HUB_DARK       = (32, 24, 20)
MINUTE_HAND    = (90, 86, 80)
WRENCH         = (255, 107, 53)
WRENCH_SHADE   = (200, 70, 30)
WRENCH_HI      = (255, 180, 140)


def draw_background() -> Image.Image:
    img = Image.new("RGB", (SIZE, SIZE), BG_OUTER)
    draw = ImageDraw.Draw(img)
    cx, cy = SIZE / 2, SIZE / 2
    max_r = SIZE * 0.72
    steps = 80
    for i in range(steps, 0, -1):
        t = i / steps
        r = max_r * t
        a = 1 - t
        color = (
            int(BG_OUTER[0] + (BG_INNER[0] - BG_OUTER[0]) * a),
            int(BG_OUTER[1] + (BG_INNER[1] - BG_OUTER[1]) * a),
            int(BG_OUTER[2] + (BG_INNER[2] - BG_OUTER[2]) * a),
        )
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    return img


def draw_clock_face() -> Image.Image:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = SIZE / 2, SIZE / 2
    radius = SIZE * 0.40

    # Soft drop shadow under the dial
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse(
        [cx - radius - 6, cy - radius - 6 + 18,
         cx + radius + 6, cy + radius + 6 + 18],
        fill=(0, 0, 0, 200),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=24))
    layer.alpha_composite(shadow)

    # Concentric bezel rings (subtle 3D edge)
    for inset in range(0, 12, 2):
        ring_r = radius + 6 - inset
        t = inset / 12
        col = (
            int(FACE_DEEP[0] + (FACE_EDGE[0] - FACE_DEEP[0]) * t),
            int(FACE_DEEP[1] + (FACE_EDGE[1] - FACE_DEEP[1]) * t),
            int(FACE_DEEP[2] + (FACE_EDGE[2] - FACE_DEEP[2]) * t),
            255,
        )
        d.ellipse([cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r], fill=col)

    # Main face
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=FACE)

    # 12 tick marks (long at 12/3/6/9, short elsewhere)
    tick_outer_r = radius - 18
    long_inner_r = radius - 64
    short_inner_r = radius - 42
    for i in range(12):
        angle_deg = i * 30 - 90
        rad = math.radians(angle_deg)
        cos_a, sin_a = math.cos(rad), math.sin(rad)
        is_major = (i % 3 == 0)
        inner_r = long_inner_r if is_major else short_inner_r
        color = TICK_MAJOR if is_major else TICK_MINOR
        width = 14 if is_major else 7
        x1 = cx + cos_a * tick_outer_r
        y1 = cy + sin_a * tick_outer_r
        x2 = cx + cos_a * inner_r
        y2 = cy + sin_a * inner_r
        d.line([(x1, y1), (x2, y2)], fill=color, width=width)

    return layer


def draw_minute_hand() -> Image.Image:
    """Thin gray hand pointing at ~11 o'clock — composes nicely with the 4 o'clock wrench."""
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = SIZE / 2, SIZE / 2

    # 11 o'clock = 330° on the clock = -30° from "12 up".
    # Convert to screen coordinates (0° = right, +y = down).
    clock_deg = -30
    rad = math.radians(clock_deg - 90)
    length = SIZE * 0.34                 # slightly longer than the wrench (minute > hour convention)
    tail = SIZE * 0.025
    x_tip = cx + math.cos(rad) * length
    y_tip = cy + math.sin(rad) * length
    x_back = cx - math.cos(rad) * tail
    y_back = cy - math.sin(rad) * tail

    # Drop shadow
    sh = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.line([(x_back + 4, y_back + 4), (x_tip + 4, y_tip + 4)],
            fill=(0, 0, 0, 180), width=20)
    sh = sh.filter(ImageFilter.GaussianBlur(radius=6))
    layer.alpha_composite(sh)

    d.line([(x_back, y_back), (x_tip, y_tip)], fill=MINUTE_HAND, width=18)
    tip_r = 9
    d.ellipse([x_tip - tip_r, y_tip - tip_r, x_tip + tip_r, y_tip + tip_r], fill=MINUTE_HAND)
    return layer


def draw_wrench_hand() -> Image.Image:
    """Bold amber wrench used as the hour hand. Pivots at the clock center,
    head pointing at ~4 o'clock."""
    buf = int(SIZE * 1.4)
    cx, cy = buf / 2, buf / 2

    total_length = SIZE * 0.32          # fits inside the 0.40-radius dial
    handle_thick = SIZE * 0.058
    head_outer = SIZE * 0.072
    head_inner_hex = head_outer * 0.55

    # Horizontal frame: pivot at center (cx,cy), head on the right tip.
    # No tail behind the pivot — the hub disc covers that end.
    x_left = cx
    x_right = cx + total_length

    solid = Image.new("RGBA", (buf, buf), (0, 0, 0, 0))
    sd = ImageDraw.Draw(solid)

    # Handle
    sd.rounded_rectangle(
        [x_left, cy - handle_thick / 2,
         x_right - head_outer * 0.5, cy + handle_thick / 2],
        radius=handle_thick / 2,
        fill=WRENCH,
    )
    # Head disc
    head_cx = x_right - head_outer * 0.30
    head_cy = cy
    sd.ellipse(
        [head_cx - head_outer, head_cy - head_outer,
         head_cx + head_outer, head_cy + head_outer],
        fill=WRENCH,
    )

    # Hex cutout in the head (true alpha — face shows through)
    mask = Image.new("L", (buf, buf), 0)
    md = ImageDraw.Draw(mask)
    hex_pts = []
    for i in range(12):
        a = math.radians(i * 30 + 15)
        hex_pts.append((head_cx + math.cos(a) * head_inner_hex,
                        head_cy + math.sin(a) * head_inner_hex))
    md.polygon(hex_pts, fill=255)
    inverted = mask.point(lambda v: 255 - v)
    solid.putalpha(ImageChops.multiply(solid.split()[3], inverted))

    # Shading band (volume on the bottom edge)
    shade = Image.new("RGBA", (buf, buf), (0, 0, 0, 0))
    sh_d = ImageDraw.Draw(shade)
    sh_d.rectangle(
        [x_left + 4, cy + handle_thick / 2 - handle_thick * 0.32,
         x_right - head_outer * 0.4, cy + handle_thick / 2],
        fill=WRENCH_SHADE,
    )
    shade.putalpha(ImageChops.multiply(shade.split()[3], solid.split()[3]))
    solid.alpha_composite(shade)

    # Highlight band (top edge)
    hl = Image.new("RGBA", (buf, buf), (0, 0, 0, 0))
    hl_d = ImageDraw.Draw(hl)
    hl_d.rectangle(
        [x_left + 4, cy - handle_thick / 2,
         x_right - head_outer * 0.4, cy - handle_thick / 2 + handle_thick * 0.18],
        fill=WRENCH_HI,
    )
    hl.putalpha(ImageChops.multiply(hl.split()[3], solid.split()[3]))
    solid.alpha_composite(hl)

    # Drop shadow
    shadow_solid = Image.new("RGBA", (buf, buf), (0, 0, 0, 255))
    shadow_solid.putalpha(solid.split()[3].point(lambda v: int(v * 0.78)))
    shadow_blurred = shadow_solid.filter(ImageFilter.GaussianBlur(radius=18))

    final_buf = Image.new("RGBA", (buf, buf), (0, 0, 0, 0))
    offset = int(SIZE * 0.014)
    final_buf.alpha_composite(shadow_blurred, (offset, offset))
    final_buf.alpha_composite(solid)

    # Rotate to point at 4 o'clock. On a clock, 4 o'clock is 120° clockwise from
    # 12 = 30° clockwise from 3 o'clock (right). In PIL (positive = counterclockwise),
    # this is -30°. But PIL rotates around image center, which is also the pivot —
    # exactly what we want since the hub of the wrench is near the center.
    rotated = final_buf.rotate(-60, resample=Image.BICUBIC)

    crop_x = (buf - SIZE) // 2
    crop_y = (buf - SIZE) // 2
    return rotated.crop((crop_x, crop_y, crop_x + SIZE, crop_y + SIZE))


def draw_hub() -> Image.Image:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = SIZE / 2, SIZE / 2
    outer = SIZE * 0.030
    inner = SIZE * 0.014
    d.ellipse([cx - outer, cy - outer, cx + outer, cy + outer], fill=HUB_DARK)
    d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=WRENCH)
    return layer


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    bg = draw_background()
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    overlay.alpha_composite(draw_clock_face())
    overlay.alpha_composite(draw_minute_hand())
    overlay.alpha_composite(draw_wrench_hand())
    overlay.alpha_composite(draw_hub())

    final = Image.alpha_composite(bg.convert("RGBA"), overlay).convert("RGB")
    final.save(OUT_PATH, "PNG", optimize=True)

    print(f"✓ Wrote {OUT_PATH} ({OUT_PATH.stat().st_size // 1024} KB)")
    print(f"✓ Size: {final.size}, mode: {final.mode} (no alpha)")


if __name__ == "__main__":
    main()
