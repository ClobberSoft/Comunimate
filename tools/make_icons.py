"""Render the controller button icons used by the Comunimate add-on.

Writes 64x64 uncompressed 32-bit TGA files (the format WoW loads reliably) to
Comunimate/Media/Icons/<style>/. Re-run after changing anything here:

    ComunimateVoice\\.venv\\Scripts\\python.exe tools\\make_icons.py
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Comunimate" / "Media" / "Icons"
S = 256          # drawing size (4x supersampled)
FINAL = 64
FONT = "C:/Windows/Fonts/arialbd.ttf"

BG = (30, 31, 38, 255)
RIM = (120, 122, 135, 255)
WHITE = (240, 240, 245, 255)
DIM = (95, 97, 110, 255)

PS_BLUE, PS_RED, PS_PINK, PS_GREEN = (124, 170, 255, 255), (255, 102, 102, 255), (255, 140, 214, 255), (92, 222, 140, 255)
XB_GREEN, XB_RED, XB_BLUE, XB_YELLOW = (92, 210, 110, 255), (255, 95, 95, 255), (90, 150, 255, 255), (255, 210, 80, 255)


def canvas():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def font(size):
    return ImageFont.truetype(FONT, size)


def centered_text(d, text, size, fill, dy=0):
    f = font(size)
    l, t, r, b = d.textbbox((0, 0), text, font=f)
    d.text(((S - (r - l)) / 2 - l, (S - (b - t)) / 2 - t + dy), text, font=f, fill=fill)


def round_face(d):
    d.ellipse((10, 10, 246, 246), fill=BG, outline=RIM, width=10)


def pill(d):
    d.rounded_rectangle((6, 52, 250, 204), radius=70, fill=BG, outline=RIM, width=10)


def trigger(d):
    d.rounded_rectangle((26, 18, 230, 238), radius=56, fill=BG, outline=RIM, width=10)


# ---- individual icons -------------------------------------------------------

def ps_cross():
    img, d = canvas(); round_face(d)
    d.line((84, 84, 172, 172), fill=PS_BLUE, width=22)
    d.line((172, 84, 84, 172), fill=PS_BLUE, width=22)
    return img


def ps_circle():
    img, d = canvas(); round_face(d)
    d.ellipse((76, 76, 180, 180), outline=PS_RED, width=20)
    return img


def ps_square():
    img, d = canvas(); round_face(d)
    d.rectangle((82, 82, 174, 174), outline=PS_PINK, width=20)
    return img


def ps_triangle():
    img, d = canvas(); round_face(d)
    pts = [(128, 66), (190, 172), (66, 172)]
    d.line(pts + [pts[0], pts[1]], fill=PS_GREEN, width=20, joint="curve")
    return img


def letter(ch, color):
    def make():
        img, d = canvas(); round_face(d)
        centered_text(d, ch, 150, color)
        return img
    return make


def pill_text(text, shape=pill, size=104):
    def make():
        img, d = canvas(); shape(d)
        centered_text(d, text, size, WHITE)
        return img
    return make


def stick(text, ring=True):
    def make():
        img, d = canvas(); round_face(d)
        if ring:
            d.ellipse((52, 52, 204, 204), outline=DIM, width=8)
        centered_text(d, text, 104 if len(text) > 1 else 130, WHITE)
        return img
    return make


def dpad(active):
    def make():
        img, d = canvas()
        arms = {
            "up": (92, 8, 164, 100), "down": (92, 156, 164, 248),
            "left": (8, 92, 100, 164), "right": (156, 92, 248, 164),
        }
        d.rectangle((92, 92, 164, 164), fill=BG)
        for name, box in arms.items():
            d.rounded_rectangle(box, radius=14, fill=WHITE if name == active else BG,
                                outline=RIM, width=8)
        d.rectangle((96, 96, 160, 160), fill=BG)
        return img
    return make


def hamburger():
    img, d = canvas(); pill(d)
    for y in (96, 128, 160):
        d.line((84, y, 172, y), fill=WHITE, width=14)
    return img


def view():
    img, d = canvas(); pill(d)
    d.rectangle((70, 84, 146, 148), outline=WHITE, width=12)
    d.rectangle((110, 112, 186, 176), fill=BG, outline=WHITE, width=12)
    return img


def share_arrow():
    img, d = canvas(); pill(d)
    d.line((96, 168, 96, 120, 160, 120), fill=WHITE, width=14, joint="curve")
    d.polygon([(150, 96), (184, 120), (150, 144)], fill=WHITE)
    return img


def create():
    img, d = canvas(); pill(d)
    for x in (98, 128, 158):
        d.line((x - 10, 156, x + 10, 100), fill=WHITE, width=14)
    return img


def dots():
    img, d = canvas(); pill(d)
    for x in (88, 128, 168):
        d.ellipse((x - 14, 114, x + 14, 142), fill=WHITE)
    return img


def mic(color=WHITE, bg=BG):
    def make():
        img, d = canvas()
        d.ellipse((10, 10, 246, 246), fill=bg, outline=RIM, width=10)
        d.rounded_rectangle((100, 48, 156, 150), radius=28, fill=color)
        d.arc((76, 86, 180, 178), start=0, end=180, fill=color, width=12)
        d.line((128, 178, 128, 206), fill=color, width=12)
        d.line((98, 206, 158, 206), fill=color, width=12)
        return img
    return make


# ---- icon sets -------------------------------------------------------------

COMMON = {
    "dpad_up": dpad("up"), "dpad_down": dpad("down"),
    "dpad_left": dpad("left"), "dpad_right": dpad("right"),
    "mic": mic(), "mic_live": mic(WHITE, (190, 40, 40, 255)),
}

SETS = {
    "ps": {
        "cross": ps_cross, "circle": ps_circle, "square": ps_square, "triangle": ps_triangle,
        "l1": pill_text("L1"), "r1": pill_text("R1"),
        "l2": pill_text("L2", trigger, 110), "r2": pill_text("R2", trigger, 110),
        "l3": stick("L3"), "r3": stick("R3"), "lstick": stick("L"), "rstick": stick("R"),
        "options": hamburger, "create": create,
    },
    "xbox": {
        "a": letter("A", XB_GREEN), "b": letter("B", XB_RED),
        "x": letter("X", XB_BLUE), "y": letter("Y", XB_YELLOW),
        "lb": pill_text("LB"), "rb": pill_text("RB"),
        "lt": pill_text("LT", trigger, 110), "rt": pill_text("RT", trigger, 110),
        "ls": stick("LS"), "rs": stick("RS"), "lstick": stick("L"), "rstick": stick("R"),
        "menu": hamburger, "view": view, "share": share_arrow,
    },
    "steam": {
        "a": letter("A", XB_GREEN), "b": letter("B", XB_RED),
        "x": letter("X", XB_BLUE), "y": letter("Y", XB_YELLOW),
        "l1": pill_text("L1"), "r1": pill_text("R1"),
        "l2": pill_text("L2", trigger, 110), "r2": pill_text("R2", trigger, 110),
        "l3": stick("L3"), "r3": stick("R3"), "lstick": stick("L"), "rstick": stick("R"),
        "l4": pill_text("L4"), "r4": pill_text("R4"), "l5": pill_text("L5"), "r5": pill_text("R5"),
        "menu": hamburger, "view": view, "dots": dots,
    },
}


def write_tga(img: Image.Image, path: Path) -> None:
    """Uncompressed 32-bit BGRA TGA, bottom-left origin."""
    img = img.convert("RGBA").transpose(Image.FLIP_TOP_BOTTOM)
    w, h = img.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    r, g, b, a = img.split()
    data = Image.merge("RGBA", (b, g, r, a)).tobytes()
    path.write_bytes(header + data)


def main() -> None:
    count = 0
    rows = []
    for style, icons in SETS.items():
        folder = OUT / style
        folder.mkdir(parents=True, exist_ok=True)
        row = []
        for name, make in {**COMMON, **icons}.items():
            img = make().resize((FINAL, FINAL), Image.LANCZOS)
            write_tga(img, folder / f"{name}.tga")
            row.append(img)
            count += 1
        rows.append(row)

    # Contact sheet for a quick visual check (not used by the add-on).
    cols = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (cols * (FINAL + 8), len(rows) * (FINAL + 8)), (12, 12, 16, 255))
    for y, row in enumerate(rows):
        for x, img in enumerate(row):
            sheet.alpha_composite(img, (x * (FINAL + 8) + 4, y * (FINAL + 8) + 4))
    sheet.save(ROOT / "tools" / "icons_preview.png")
    print(f"wrote {count} icons to {OUT}")

    # The orc mascot for the in-game badge (our own art, shared with the tray icon).
    sys.path.insert(0, str(ROOT / "ComunimateVoice"))
    import orc_art
    media = ROOT / "Comunimate" / "Media"
    write_tga(orc_art.orc_image(False, 128, ring=True), media / "orc_quiet.tga")
    write_tga(orc_art.orc_image(True, 128, ring=True), media / "orc_yell.tga")
    # The see-through ring cursor for the keyboard (tinted per side in game).
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    d.ellipse((14, 14, S - 14, S - 14), fill=(255, 255, 255, 40), outline=(255, 255, 255, 255), width=22)
    write_tga(ring.resize((64, 64), Image.LANCZOS), media / "ring.tga")
    # Soft glow for the swipe light trail: bright down the middle, fading to
    # nothing at the edges (WoW stretches it along each trail segment).
    import math
    glow = Image.new("RGBA", (64, 32), (255, 255, 255, 0))
    for y in range(32):
        a = int(255 * math.exp(-((y - 15.5) / 6.5) ** 2))
        for x in range(64):
            glow.putpixel((x, y), (255, 255, 255, a))
    write_tga(glow, media / "trail_glow.tga")
    print("wrote orc and ring textures")

    # Gold frame drawn over the mascot in game (Settings > Badge > Gold frame).
    # The mascot pictures themselves come from art: tools/mascot_art.py import.
    import portraits
    frame = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.ellipse((4, 4, 508, 508), outline=portraits.GOLD_DARK, width=26)
    d.ellipse((9, 9, 503, 503), outline=portraits.GOLD, width=14)
    d.ellipse((24, 24, 488, 488), outline=(60, 40, 12, 200), width=4)
    write_tga(frame.resize((256, 256), Image.LANCZOS), media / "frame_gold.tga")
    print("wrote gold frame")


if __name__ == "__main__":
    main()
