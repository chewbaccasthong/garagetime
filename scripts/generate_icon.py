#!/usr/bin/env python3
"""
Generate the GarageTime AppIcon master (1024x1024 PNG, NO alpha).

Design: a chunky combination wrench laid diagonally across an open book.
- Background: brand near-black with subtle vignette
- Book: cream pages opening like a wedge, dark spine, soft text rules
- Wrench: brake-light amber with true transparent cutouts — the book pages
  show through the loop end and the open jaw

Apple's icon mask rounds the corners automatically (we draw a flat square).
Apple rejects icons with an alpha channel, so the output is RGB.
"""
from __future__ import annotations
import math
import pathlib
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT_DIR = pathlib.Path(__file__).resolve().parent.parent / "GarageTime" / "Assets.xcassets" / "AppIcon.appiconset"
OUT_PATH = OUT_DIR / "icon-1024.png"

# Brand palette
BG_OUTER       = (10, 10, 12)
BG_INNER       = (34, 32, 38)
PAGE           = (244, 240, 228)
PAGE_EDGE      = (215, 205, 185)
PAGE_DEEP      = (175, 162, 142)
SPINE_DARK     = (28, 22, 18)
RULES          = (160, 148, 128)
WRENCH         = (255, 107, 53)
WRENCH_SHADE   = (200, 70, 30)
WRENCH_HI      = (255, 180, 140)


# ---------- background ----------

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


# ---------- book ----------

def draw_book() -> Image.Image:
    """Open book seen from slightly above. RGBA so we can composite on the bg."""
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    cx, cy = SIZE / 2, SIZE / 2
    half_w = SIZE * 0.42
    half_h = SIZE * 0.30
    perspective = SIZE * 0.05    # top tucks inward

    # Drop shadow first — a soft fuzzy oval below the book
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse(
        [cx - half_w * 1.05, cy + half_h - 10,
         cx + half_w * 1.05, cy + half_h + 60],
        fill=(0, 0, 0, 180),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=22))
    layer.alpha_composite(shadow)

    # Page-stack edge under each page (gives the book real thickness)
    edge_drop = 16
    stack_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sld = ImageDraw.Draw(stack_layer)
    for d_offset in range(edge_drop, 0, -2):
        t = d_offset / edge_drop
        col_l = (
            int(PAGE_DEEP[0] + (PAGE_EDGE[0] - PAGE_DEEP[0]) * (1 - t)),
            int(PAGE_DEEP[1] + (PAGE_EDGE[1] - PAGE_DEEP[1]) * (1 - t)),
            int(PAGE_DEEP[2] + (PAGE_EDGE[2] - PAGE_DEEP[2]) * (1 - t)),
            255,
        )
        left_stack = [
            (cx - half_w * 1.02, cy + half_h + d_offset),
            (cx,                  cy + half_h * 0.92 + d_offset),
            (cx,                  cy + half_h * 0.92),
            (cx - half_w * 1.02,  cy + half_h),
        ]
        right_stack = [
            (cx,                  cy + half_h * 0.92 + d_offset),
            (cx + half_w * 1.02,  cy + half_h + d_offset),
            (cx + half_w * 1.02,  cy + half_h),
            (cx,                  cy + half_h * 0.92),
        ]
        sld.polygon(left_stack, fill=col_l)
        sld.polygon(right_stack, fill=col_l)
    layer.alpha_composite(stack_layer)

    # Top page surfaces
    left_page = [
        (cx - half_w * 1.02, cy + half_h),
        (cx,                  cy + half_h * 0.92),
        (cx,                  cy - half_h * 0.96 + 6),
        (cx - half_w + perspective, cy - half_h + 6),
    ]
    right_page = [
        (cx,                  cy + half_h * 0.92),
        (cx + half_w * 1.02,  cy + half_h),
        (cx + half_w - perspective, cy - half_h + 6),
        (cx,                  cy - half_h * 0.96 + 6),
    ]
    d.polygon(left_page, fill=PAGE)
    d.polygon(right_page, fill=PAGE)

    # (No outer page-curl shading — looked like a stray triangle.)

    # Center spine — darker valley
    spine_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sl = ImageDraw.Draw(spine_layer)
    sl.polygon([
        (cx - 14, cy - half_h * 0.96 + 6),
        (cx + 14, cy - half_h * 0.96 + 6),
        (cx + 10, cy + half_h * 0.92),
        (cx - 10, cy + half_h * 0.92),
    ], fill=(0, 0, 0, 90))
    sl.line(
        [(cx, cy - half_h * 0.96 + 6), (cx, cy + half_h * 0.92)],
        fill=SPINE_DARK, width=4
    )
    layer.alpha_composite(spine_layer)

    # Text rules — subtle horizontal lines on both pages
    rule_count = 6
    rule_pad_x = half_w * 0.18
    top_pad = half_h * 0.34
    bottom_pad = half_h * 0.18
    rule_h_span = half_h * 1.86
    rule_color = (*RULES, 180)
    for i in range(rule_count):
        t = i / max(rule_count - 1, 1)
        y = cy - rule_h_span / 2 + top_pad + t * (rule_h_span - top_pad - bottom_pad)
        # Left
        d.line(
            [(cx - half_w + rule_pad_x + perspective * (1 - t * 0.5), y),
             (cx - rule_pad_x * 0.6, y)],
            fill=rule_color, width=5
        )
        # Right
        d.line(
            [(cx + rule_pad_x * 0.6, y),
             (cx + half_w - rule_pad_x - perspective * (1 - t * 0.5), y)],
            fill=rule_color, width=5
        )

    return layer


# ---------- wrench (with true transparent cutouts) ----------

def draw_wrench(angle_deg: float = -30) -> Image.Image:
    """Returns an RGBA layer the size of SIZE x SIZE with a chunky combo wrench."""
    # Work in an oversized buffer so rotation doesn't clip
    buf = int(SIZE * 1.4)
    cx, cy = buf / 2, buf / 2

    # Dimensions
    handle_len = SIZE * 0.78
    handle_thick = SIZE * 0.095
    closed_outer = SIZE * 0.14
    closed_inner = closed_outer * 0.55
    open_outer = SIZE * 0.14
    jaw_gap = open_outer * 0.55      # opening width
    jaw_depth = open_outer * 1.05     # how deep the notch cuts

    x_left = cx - handle_len / 2
    x_right = cx + handle_len / 2

    # Build the wrench SOLID shape on its own RGBA layer (no cutouts yet)
    solid = Image.new("RGBA", (buf, buf), (0, 0, 0, 0))
    sd = ImageDraw.Draw(solid)

    # Handle as rounded rectangle
    sd.rounded_rectangle(
        [x_left + closed_outer * 0.5, cy - handle_thick / 2,
         x_right - open_outer * 0.5,  cy + handle_thick / 2],
        radius=handle_thick / 2,
        fill=WRENCH,
    )

    # CLOSED loop end (left) — solid disc
    closed_cx = x_left + closed_outer * 0.85
    closed_cy = cy
    sd.ellipse(
        [closed_cx - closed_outer, closed_cy - closed_outer,
         closed_cx + closed_outer, closed_cy + closed_outer],
        fill=WRENCH,
    )

    # OPEN jaw end (right) — chunky D-shape so the slot reads as a slot, not a Pac-Man bite
    jaw_cx = x_right - open_outer * 0.85
    jaw_cy = cy
    # Main body: a slightly-flattened oval (taller than wide gives the open-end-wrench look)
    sd.ellipse(
        [jaw_cx - open_outer * 0.95, jaw_cy - open_outer * 1.05,
         jaw_cx + open_outer * 0.95, jaw_cy + open_outer * 1.05],
        fill=WRENCH,
    )
    # Fill in the corner toward the handle so it joins cleanly
    sd.rectangle(
        [jaw_cx - open_outer * 0.95, jaw_cy - handle_thick * 0.95,
         jaw_cx,                      jaw_cy + handle_thick * 0.95],
        fill=WRENCH,
    )

    # Now build CUTOUT mask — black where wrench should be holed out
    mask = Image.new("L", (buf, buf), 0)
    md = ImageDraw.Draw(mask)
    # Hex hole at closed end
    hex_pts = []
    for i in range(12):
        a = math.radians(i * (360 / 12) + 15)
        hex_pts.append((closed_cx + math.cos(a) * closed_inner,
                        closed_cy + math.sin(a) * closed_inner))
    md.polygon(hex_pts, fill=255)
    # Open jaw slot — a clean rectangular notch cut from the far (right) edge
    # toward the handle. Bigger gap + deeper cut so the two prongs read at small sizes.
    slot_width = open_outer * 0.72          # gap between the two prongs
    slot_depth = open_outer * 1.30          # how deep into the head it cuts
    slot_outer_x = jaw_cx + open_outer * 1.40   # well past the edge so the cut breaks the silhouette
    slot_inner_x = slot_outer_x - slot_depth
    md.rounded_rectangle(
        [slot_inner_x, jaw_cy - slot_width / 2,
         slot_outer_x, jaw_cy + slot_width / 2],
        radius=slot_width * 0.12,
        fill=255,
    )

    # Apply cutouts by zeroing alpha where mask is set
    solid_alpha = solid.split()[3]
    # New alpha = solid_alpha AND NOT mask
    inverted_mask = mask.point(lambda v: 255 - v)
    combined_alpha = Image.eval(solid_alpha, lambda v: v)
    # Multiply alpha by inverted mask
    new_alpha = Image.new("L", (buf, buf), 0)
    for src_band, mask_band in [(solid_alpha, inverted_mask)]:
        # PIL: ImageChops.multiply is on Images, so wrap
        from PIL import ImageChops
        new_alpha = ImageChops.multiply(src_band, mask_band)
    solid.putalpha(new_alpha)

    # SHADING: a darker band along the bottom edge of the handle for volume
    shade_layer = Image.new("RGBA", (buf, buf), (0, 0, 0, 0))
    sl = ImageDraw.Draw(shade_layer)
    sl.rectangle(
        [x_left + closed_outer * 0.3, cy + handle_thick / 2 - handle_thick * 0.32,
         x_right - open_outer * 0.3,  cy + handle_thick / 2],
        fill=WRENCH_SHADE,
    )
    # Clip the shading to the wrench shape
    shade_layer = clip_to_alpha(shade_layer, solid.split()[3])
    solid.alpha_composite(shade_layer)

    # HIGHLIGHT band along top edge
    hl_layer = Image.new("RGBA", (buf, buf), (0, 0, 0, 0))
    hl = ImageDraw.Draw(hl_layer)
    hl.rectangle(
        [x_left + closed_outer * 0.3, cy - handle_thick / 2,
         x_right - open_outer * 0.3,  cy - handle_thick / 2 + handle_thick * 0.18],
        fill=WRENCH_HI,
    )
    hl_layer = clip_to_alpha(hl_layer, solid.split()[3])
    solid.alpha_composite(hl_layer)

    # DROP SHADOW — soft black underneath
    shadow_src = Image.new("RGBA", (buf, buf), (0, 0, 0, 0))
    ss = ImageDraw.Draw(shadow_src)
    # Paint the solid shape silhouette
    ss.bitmap((0, 0), solid.split()[3].convert("L"), fill=(0, 0, 0, 220))
    # Better: just composite solid alpha as shadow
    shadow_src = Image.new("RGBA", (buf, buf), (0, 0, 0, 0))
    shadow_src.putalpha(solid.split()[3].point(lambda v: int(v * 0.78)))
    # Apply pure black RGB
    shadow_solid = Image.new("RGBA", (buf, buf), (0, 0, 0, 255))
    shadow_solid.putalpha(solid.split()[3].point(lambda v: int(v * 0.7)))
    shadow_blurred = shadow_solid.filter(ImageFilter.GaussianBlur(radius=22))

    # Composite: shadow (offset) under the wrench
    offset = int(SIZE * 0.018)
    final_buf = Image.new("RGBA", (buf, buf), (0, 0, 0, 0))
    final_buf.alpha_composite(shadow_blurred, (offset, offset))
    final_buf.alpha_composite(solid)

    # Rotate
    rotated = final_buf.rotate(angle_deg, resample=Image.BICUBIC)

    # Crop to SIZE x SIZE centered
    crop_x = (buf - SIZE) // 2
    crop_y = (buf - SIZE) // 2
    cropped = rotated.crop((crop_x, crop_y, crop_x + SIZE, crop_y + SIZE))
    return cropped


def clip_to_alpha(rgba_img: Image.Image, alpha: Image.Image) -> Image.Image:
    """Multiply the rgba_img's alpha channel by the supplied alpha mask."""
    from PIL import ImageChops
    src_a = rgba_img.split()[3]
    new_a = ImageChops.multiply(src_a, alpha)
    out = rgba_img.copy()
    out.putalpha(new_a)
    return out


# ---------- main ----------

def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    bg = draw_background()                 # RGB
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    overlay.alpha_composite(draw_book())
    overlay.alpha_composite(draw_wrench(angle_deg=-30))

    final = Image.alpha_composite(bg.convert("RGBA"), overlay).convert("RGB")
    final.save(OUT_PATH, "PNG", optimize=True)

    print(f"✓ Wrote {OUT_PATH} ({OUT_PATH.stat().st_size // 1024} KB)")
    print(f"✓ Size: {final.size}, mode: {final.mode} (no alpha)")


if __name__ == "__main__":
    main()
