"""Comunimate's orc mascot, drawn in code (our own cartoon, not game art).

    whistling  mic off: happy closed "U U" anime eyes, puckered lips, music notes
    yelling    mic on: squeezed ">  <" eyes, huge open mouth, shout lines

Used for the tray icon (helper.py) and exported as textures for the in-game
badge (tools/make_icons.py).
"""
from __future__ import annotations

from PIL import Image, ImageDraw

S = 512  # drawing size; scaled down at the end for smooth edges

INK = (28, 34, 22, 255)
SKIN = (138, 194, 86, 255)
SKIN_SHADE = (112, 166, 68, 255)
TUSK = (252, 247, 228, 255)
BLUSH = (255, 128, 140, 150)
HAIR = (34, 30, 28, 255)
WHITE = (255, 255, 255, 255)
MOUTH = (70, 18, 24, 255)
TONGUE = (226, 92, 104, 255)
GOLD = (222, 178, 70, 255)
GOLD_DARK = (120, 86, 28, 255)

QUIET_GREEN = (52, 168, 90)
SPEAKING_RED = (210, 48, 48)


def _note(d: ImageDraw.ImageDraw, x: int, y: int, scale: float = 1.0) -> None:
    """A music note (eighth note) with its head at x, y."""
    r = 20 * scale
    sx = x + r * 1.1
    top = y - 82 * scale
    flag = (sx, top, sx + 34 * scale, top + 26 * scale)
    # Ink outline first, then the white note on top.
    for color, grow in ((INK, 7), (WHITE, 0)):
        d.ellipse((x - r * 1.3 - grow, y - r - grow, x + r * 1.3 + grow, y + r + grow), fill=color)
        d.line((sx, y, sx, top), fill=color, width=int(10 * scale) + grow * 2)
        d.line(flag, fill=color, width=int(10 * scale) + grow * 2)


def _head(d: ImageDraw.ImageDraw, yelling: bool) -> None:
    # Top knot.
    d.ellipse((222, 46, 290, 112), fill=HAIR, outline=INK, width=8)
    d.rectangle((246, 100, 266, 128), fill=HAIR)
    # Ears: big, pointy, a little floppy.
    d.polygon([(132, 214), (34, 150), (90, 262), (140, 286)], fill=SKIN, outline=INK, width=10)
    d.polygon([(380, 214), (478, 150), (422, 262), (372, 286)], fill=SKIN, outline=INK, width=10)
    d.polygon([(118, 222), (70, 186), (104, 250)], fill=SKIN_SHADE)
    d.polygon([(394, 222), (442, 186), (408, 250)], fill=SKIN_SHADE)
    # Head: round top, big jaw.
    top = 110 if not yelling else 100
    d.rounded_rectangle((116, top, 396, 456), radius=130, fill=SKIN, outline=INK, width=12)
    # Jaw shading.
    d.chord((132, 300, 380, 450), start=0, end=180, fill=SKIN_SHADE)
    # Heavy brow.
    if yelling:
        d.line((158, 192, 236, 226), fill=INK, width=22)
        d.line((276, 226, 354, 192), fill=INK, width=22)
    else:
        d.arc((160, 170, 246, 230), start=200, end=340, fill=INK, width=16)
        d.arc((266, 170, 352, 230), start=200, end=340, fill=INK, width=16)


def draw_whistling(d: ImageDraw.ImageDraw) -> None:
    _head(d, yelling=False)
    # Happy closed eyes: "U U".
    d.arc((168, 214, 236, 280), start=0, end=180, fill=INK, width=14)
    d.arc((276, 214, 344, 280), start=0, end=180, fill=INK, width=14)
    # Blush.
    d.ellipse((150, 290, 206, 322), fill=BLUSH)
    d.ellipse((306, 290, 362, 322), fill=BLUSH)
    # Small tusks resting on the upper lip.
    d.polygon([(206, 380), (214, 322), (232, 378)], fill=TUSK, outline=INK, width=6)
    d.polygon([(306, 380), (298, 322), (280, 378)], fill=TUSK, outline=INK, width=6)
    # Puckered whistling lips, off to one side.
    d.ellipse((262, 340, 316, 392), fill=SKIN_SHADE, outline=INK, width=10)
    d.ellipse((280, 356, 298, 376), fill=MOUTH)


def draw_yelling(d: ImageDraw.ImageDraw) -> None:
    _head(d, yelling=True)
    # Squeezed anime eyes: >  <
    d.line((172, 238, 222, 258), fill=INK, width=14)
    d.line((222, 258, 172, 280), fill=INK, width=14)
    d.line((340, 238, 290, 258), fill=INK, width=14)
    d.line((290, 258, 340, 280), fill=INK, width=14)
    # Huge open mouth with tongue.
    d.ellipse((170, 290, 342, 448), fill=MOUTH, outline=INK, width=12)
    d.ellipse((212, 378, 300, 440), fill=TONGUE)
    # Big tusks pointing up from the lower jaw.
    d.polygon([(184, 408), (196, 300), (226, 404)], fill=TUSK, outline=INK, width=7)
    d.polygon([(328, 408), (316, 300), (286, 404)], fill=TUSK, outline=INK, width=7)
    # Shout lines.
    for x0, y0, x1, y1 in ((420, 250, 488, 222), (430, 320, 500, 320), (420, 390, 488, 418),
                           (92, 250, 24, 222), (82, 320, 12, 320), (92, 390, 24, 418)):
        d.line((x0, y0, x1, y1), fill=WHITE, width=16)
        d.line((x0, y0, x1, y1), fill=INK, width=5)


def orc_image(yelling: bool, size: int = 64, background: bool = True, ring: bool = False) -> Image.Image:
    """The mascot as an RGBA image.

    background: the green / red disc behind him.  ring: a gold frame (in-game badge).
    """
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if background:
        color = SPEAKING_RED if yelling else QUIET_GREEN
        d.ellipse((8, 8, S - 8, S - 8), fill=color + (255,))
    # Draw the orc on its own layer so it can be clipped to the disc.
    drawn = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    (draw_yelling if yelling else draw_whistling)(ImageDraw.Draw(drawn))
    # Shrink him a little so he sits inside the frame; while whistling, nudge
    # him left to make room for the music notes.
    scale = 0.86
    small = drawn.resize((int(S * scale), int(S * scale)), Image.LANCZOS)
    offset = int(S * (1 - scale) / 2)
    face = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    face.alpha_composite(small, (offset - (26 if not yelling else 0), offset + 8))
    if not yelling:
        fd = ImageDraw.Draw(face)
        _note(fd, 372, 380, 0.85)
        _note(fd, 414, 270, 0.7)
    if background or ring:
        # Keep the shout lines and ears inside the round frame.
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).ellipse((8, 8, S - 8, S - 8), fill=255)
        face = Image.composite(face, Image.new("RGBA", (S, S), (0, 0, 0, 0)), mask)
    img.alpha_composite(face)
    if ring:
        d = ImageDraw.Draw(img)
        d.ellipse((10, 10, S - 10, S - 10), outline=GOLD_DARK, width=34)
        d.ellipse((16, 16, S - 16, S - 16), outline=GOLD, width=20)
    return img.resize((size, size), Image.LANCZOS)
