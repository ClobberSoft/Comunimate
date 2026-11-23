"""Comunimate mascots: every playable race in three styles, drawn in code.

    races   Horde: orc, troll, tauren, undead
            Alliance: human, dwarf, nightelf, gnome
            Both: skyborne
    styles  cute   chunky cartoon (the original orc)
            epic   dark, dramatic lighting, glowing eyes, war cry
            anime  big sparkly eyes, pointed chin, speed lines
    moods   quiet (mic off) and loud (mic on)

Our own art, not game assets. portrait(race, style, loud, size) -> RGBA image.
"""
from __future__ import annotations

import math

from PIL import Image, ImageDraw, ImageFilter

S = 512
CX = 256

INK = (28, 30, 26, 255)
WHITE = (255, 255, 255, 255)
TUSK = (252, 247, 228, 255)
MOUTH = (70, 18, 24, 255)
TONGUE = (226, 92, 104, 255)
GOLD = (222, 178, 70, 255)
GOLD_DARK = (120, 86, 28, 255)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))), max(0, min(255, int(c[2] * f))))


# ----------------------------------------------------------------------------
# Races
# ----------------------------------------------------------------------------

RACES = {
    "orc": dict(name="Orc", faction="horde", skin=(138, 194, 86), ears="pointy", hair="topknot",
                hair_color=(34, 30, 28), tusks="small", nose="flat", jaw="wide", iris=(170, 60, 40)),
    "troll": dict(name="Troll", faction="horde", skin=(92, 156, 168), ears="long_low", hair="mohawk",
                  hair_color=(214, 56, 64), tusks="big", nose="long", jaw="narrow", iris=(220, 60, 50)),
    "tauren": dict(name="Tauren", faction="horde", skin=(150, 104, 70), ears="cow", hair="tuft",
                   hair_color=(84, 56, 36), nose="muzzle", jaw="wide", horns=True, iris=(110, 70, 40)),
    "undead": dict(name="Undead", faction="horde", skin=(168, 178, 158), ears="human", hair="stringy",
                   hair_color=(64, 56, 70), nose="hollow", jaw="narrow", eye_glow=(255, 214, 60),
                   undead=True, iris=(255, 214, 60)),
    "human": dict(name="Human", faction="alliance", skin=(240, 200, 166), ears="human", hair="side",
                  hair_color=(122, 80, 44), nose="small", jaw="normal", iris=(70, 120, 200)),
    "dwarf": dict(name="Dwarf", faction="alliance", skin=(234, 182, 142), ears="human", hair="bald",
                  hair_color=(160, 82, 40), nose="big", jaw="wide", beard=(160, 82, 40), iris=(90, 70, 50)),
    "nightelf": dict(name="Night Elf", faction="alliance", skin=(150, 128, 204), ears="very_long", hair="long",
                     hair_color=(56, 150, 150), nose="small", jaw="narrow", eye_glow=(220, 240, 255),
                     marks=(70, 50, 120), iris=(210, 235, 255)),
    "gnome": dict(name="Gnome", faction="alliance", skin=(250, 212, 184), ears="small_pointy", hair="pigtails",
                  hair_color=(240, 92, 170), nose="round", jaw="round", iris=(140, 80, 200)),
    "skyborne": dict(name="Skyborne", faction="both", skin=(236, 228, 242), ears="long_up", hair="swept",
                     hair_color=(220, 234, 255), nose="small", jaw="narrow", eye_glow=(150, 220, 255),
                     marks=(70, 140, 230), feather=True, iris=(140, 210, 255)),
}
ORDER = ["orc", "troll", "tauren", "undead", "human", "dwarf", "nightelf", "gnome", "skyborne"]
STYLES = ["cute", "epic", "anime"]

FACTION_COLORS = {
    "horde": ((140, 20, 18), (30, 6, 6)),
    "alliance": ((30, 70, 160), (8, 14, 40)),
    "both": ((70, 150, 220), (12, 30, 60)),
}


# ----------------------------------------------------------------------------
# Head geometry
# ----------------------------------------------------------------------------

def head_box(r):
    half = {"wide": 142, "normal": 128, "narrow": 118, "round": 146}[r["jaw"]]
    return CX - half, 128, CX + half, 452


def head_shape(d, r, style, fill, ow, ink):
    x0, y0, x1, y1 = head_box(r)
    if style == "anime":
        # Round skull, pointed chin.
        d.ellipse((x0, y0, x1, y1 - 40), fill=fill, outline=ink, width=ow)
        chin = [(x0 + 6, 300), (CX, y1 + 4), (x1 - 6, 300)]
        d.polygon(chin, fill=fill)
        d.line([chin[0], chin[1], chin[2]], fill=ink, width=ow, joint="curve")
        d.rectangle((x0 + ow, 280, x1 - ow, 318), fill=fill)
    elif style == "epic":
        # Angular, heroic jaw.
        pts = [(x0 + 24, y0 + 30), (CX, y0 - 4), (x1 - 24, y0 + 30), (x1, 280), (x1 - 30, 400),
               (CX + 40, y1), (CX - 40, y1), (x0 + 30, 400), (x0, 280)]
        d.polygon(pts, fill=fill, outline=ink, width=ow)
    else:
        d.rounded_rectangle((x0, y0, x1, y1), radius=130, fill=fill, outline=ink, width=ow)


# ----------------------------------------------------------------------------
# Parts
# ----------------------------------------------------------------------------

def ears(d, r, skin, ow, ink):
    x0, _, x1, _ = head_box(r)
    inner = rgba(shade(skin, 0.82))
    kind = r["ears"]

    def pair(left):
        right = [(2 * CX - x, y) for x, y in left]
        for poly in (left, right):
            d.polygon(poly, fill=rgba(skin), outline=ink, width=ow)

    if kind == "pointy":
        pair([(x0 + 14, 220), (x0 - 92, 156), (x0 - 30, 262), (x0 + 16, 288)])
    elif kind == "long_low":
        pair([(x0 + 12, 230), (x0 - 120, 236), (x0 - 20, 280), (x0 + 14, 292)])
    elif kind == "very_long":
        pair([(x0 + 12, 236), (x0 - 108, 96), (x0 - 24, 230), (x0 + 14, 290)])
    elif kind == "long_up":
        pair([(x0 + 12, 230), (x0 - 70, 70), (x0 - 14, 214), (x0 + 14, 288)])
    elif kind == "small_pointy":
        pair([(x0 + 12, 236), (x0 - 52, 196), (x0 - 10, 268), (x0 + 14, 286)])
    elif kind == "cow":
        for sx in (-1, 1):
            ex = CX + sx * (x1 - CX + 52)
            d.ellipse((ex - 62, 214, ex + 62, 266), fill=rgba(skin), outline=ink, width=ow)
            d.ellipse((ex - 40, 226, ex + 40, 254), fill=inner)
    else:  # human
        for sx in (-1, 1):
            ex = CX + sx * (x1 - CX + 6)
            d.ellipse((ex - 26, 236, ex + 26, 300), fill=rgba(skin), outline=ink, width=ow)


def horns(d, r, ow, ink):
    x0, y0, x1, _ = head_box(r)
    ivory = (236, 224, 196, 255)
    for sx in (-1, 1):
        bx = CX + sx * (x1 - CX - 20)
        pts = [(bx, y0 + 40), (bx + sx * 70, y0 + 10), (bx + sx * 112, y0 - 60),
               (bx + sx * 96, y0 - 70), (bx + sx * 46, y0 - 14), (bx - sx * 20, y0 + 20)]
        d.polygon(pts, fill=ivory, outline=ink, width=ow)


def hair_back(d, r, ow, ink):
    x0, y0, x1, y1 = head_box(r)
    c = rgba(r["hair_color"])
    if r["hair"] in ("long", "swept"):
        d.rounded_rectangle((x0 - 26, y0 - 6, x1 + 26, y1 - 20), radius=120, fill=c, outline=ink, width=ow)
    elif r["hair"] == "stringy":
        # A few lank strands hanging beside the face.
        for sx in (-1, 1):
            for k in range(3):
                x = CX + sx * (x1 - CX - 6 + k * 14)
                d.line((x, y0 + 40, x + sx * (6 + k * 6), y1 - 60 - k * 30), fill=c, width=14)
    elif r["hair"] == "pigtails":
        for sx in (-1, 1):
            px = CX + sx * (x1 - CX + 70)
            d.ellipse((px - 56, 250, px + 56, 370), fill=c, outline=ink, width=ow)


def anime_bangs(d, r, ow, ink):
    """Spiky anime fringe over the forehead."""
    x0, y0, x1, _ = head_box(r)
    c = rgba(r["hair_color"])
    spikes = 6
    w = (x1 - x0 - 20) / spikes
    pts = [(x0 + 4, y0 + 70)]
    for i in range(spikes):
        left = x0 + 10 + i * w
        pts += [(left + w * 0.5, y0 + 128 + (i % 2) * 18), (left + w, y0 + 72)]
    pts += [(x1 - 4, y0 + 70), (x1 - 10, y0 + 20), (CX, y0 - 30), (x0 + 10, y0 + 20)]
    d.polygon(pts, fill=c, outline=ink, width=max(3, ow // 2))


def hair_front(d, r, ow, ink, style="cute"):
    x0, y0, x1, _ = head_box(r)
    if style == "anime" and r["hair"] in ("side", "long", "swept", "pigtails", "stringy"):
        if r["hair"] == "pigtails":
            pass  # pigtails are drawn behind; bangs on top
        anime_bangs(d, r, ow, ink)
        if r.get("feather"):
            d.polygon([(x1 - 10, y0 + 30), (x1 + 70, y0 - 60), (x1 + 40, y0 + 40)], fill=(90, 170, 240, 255),
                      outline=ink, width=max(2, ow // 2))
        return
    c = rgba(r["hair_color"])
    dark = rgba(shade(r["hair_color"], 0.7))
    kind = r["hair"]
    if kind == "topknot":
        d.ellipse((CX - 34, y0 - 82, CX + 34, y0 - 16), fill=c, outline=ink, width=ow)
        d.rectangle((CX - 10, y0 - 22, CX + 10, y0 + 8), fill=c)
    elif kind == "mohawk":
        pts = [(CX - 34, y0 + 30), (CX - 40, y0 - 50), (CX - 10, y0 - 110), (CX + 10, y0 - 60),
               (CX + 40, y0 - 100), (CX + 34, y0 + 30)]
        d.polygon(pts, fill=c, outline=ink, width=ow)
    elif kind == "tuft":
        d.polygon([(CX - 60, y0 + 30), (CX - 20, y0 - 30), (CX, y0 + 10), (CX + 30, y0 - 26), (CX + 60, y0 + 30)],
                  fill=c, outline=ink, width=ow)
    elif kind == "side":
        d.chord((x0 - 6, y0 - 30, x1 + 6, y0 + 170), start=180, end=360, fill=c, outline=ink, width=ow)
        d.polygon([(CX - 40, y0 + 50), (CX + 120, y0 + 40), (x1, y0 + 100), (x1, y0 + 60)], fill=c)
    elif kind == "bald":
        d.ellipse((CX - 70, y0 + 20, CX - 20, y0 + 44), fill=(255, 255, 255, 90))
    elif kind in ("long", "swept"):
        d.chord((x0 - 10, y0 - 20, x1 + 10, y0 + 180), start=180, end=360, fill=c, outline=ink, width=ow)
        if kind == "swept":
            d.polygon([(CX - 90, y0 + 60), (CX + 60, y0 - 30), (CX + 150, y0 + 10), (CX + 10, y0 + 80)], fill=c)
            d.line((CX - 60, y0 + 50, CX + 120, y0), fill=dark, width=6)
        else:
            d.polygon([(CX - 20, y0 + 70), (CX - 120, y0 + 40), (CX - 40, y0 + 10)], fill=c)
    elif kind == "stringy":
        d.chord((x0, y0 - 10, x1, y0 + 120), start=180, end=360, fill=c)
    elif kind == "pigtails":
        d.chord((x0 - 6, y0 - 26, x1 + 6, y0 + 170), start=180, end=360, fill=c, outline=ink, width=ow)
        for i in range(-2, 3):
            d.polygon([(CX + i * 46 - 24, y0 + 40), (CX + i * 46, y0 + 96), (CX + i * 46 + 24, y0 + 40)], fill=c)
    if r.get("feather"):
        d.polygon([(x1 - 10, y0 + 30), (x1 + 70, y0 - 60), (x1 + 40, y0 + 40)], fill=(90, 170, 240, 255),
                  outline=ink, width=max(2, ow // 2))
        d.line((x1 - 6, y0 + 30, x1 + 60, y0 - 46), fill=WHITE, width=4)


def markings(d, r):
    m = r.get("marks")
    if not m:
        return
    c = rgba(m, 200)
    if r["name"] == "Night Elf":
        for sx in (-1, 1):
            d.line((CX + sx * 30, 236, CX + sx * 120, 300), fill=c, width=12)
    else:
        for sx in (-1, 1):
            for k in range(2):
                y = 318 + k * 22
                d.line((CX + sx * 92, y, CX + sx * 120, y - 12), fill=c, width=8)


# ---- eyes ------------------------------------------------------------------

EYE_Y = 262
EYE_DX = 58


def eyes(d, r, style, loud, ink):
    glow = r.get("eye_glow")
    for sx in (-1, 1):
        ex = CX + sx * EYE_DX
        if style == "cute":
            if loud:
                d.line((ex - sx * 26, EYE_Y - 20, ex + sx * 14, EYE_Y), fill=ink, width=14)
                d.line((ex + sx * 14, EYE_Y, ex - sx * 26, EYE_Y + 22), fill=ink, width=14)
            else:
                d.arc((ex - 34, EYE_Y - 34, ex + 34, EYE_Y + 30), start=0, end=180, fill=ink, width=14)
        elif style == "anime":
            if loud:
                d.ellipse((ex - 30, EYE_Y - 44, ex + 30, EYE_Y + 34), fill=WHITE, outline=ink, width=6)
                d.ellipse((ex - 22, EYE_Y - 30, ex + 22, EYE_Y + 30), fill=rgba(r["iris"]))
                d.ellipse((ex - 12, EYE_Y - 14, ex + 12, EYE_Y + 18), fill=INK)
                d.ellipse((ex - 16, EYE_Y - 26, ex - 2, EYE_Y - 12), fill=WHITE)
                d.ellipse((ex + 6, EYE_Y + 8, ex + 13, EYE_Y + 15), fill=WHITE)
                d.line((ex - 32, EYE_Y - 44, ex + 32, EYE_Y - 52 if sx < 0 else EYE_Y - 36), fill=ink, width=8)
            else:
                # Happy closed "^ ^".
                d.arc((ex - 30, EYE_Y - 16, ex + 30, EYE_Y + 40), start=200, end=340, fill=ink, width=10)
        else:  # epic
            c = rgba(glow or (255, 190, 80))
            if loud:
                d.polygon([(ex - 32, EYE_Y - 6), (ex + 30, EYE_Y - 16), (ex + 26, EYE_Y + 12), (ex - 28, EYE_Y + 10)],
                          fill=c)
                d.line((ex - sx * 40, EYE_Y - 44, ex + sx * 30, EYE_Y - 18), fill=ink, width=16)
            else:
                d.polygon([(ex - 30, EYE_Y), (ex + 28, EYE_Y - 8), (ex + 26, EYE_Y + 6), (ex - 28, EYE_Y + 8)], fill=c)
                d.line((ex - 40, EYE_Y - 28, ex + 34, EYE_Y - 24 - sx * 6), fill=ink, width=14)
    if style == "cute" and not loud:
        for sx in (-1, 1):
            ex = CX + sx * EYE_DX
            d.ellipse((ex - 34, 306, ex + 22, 334), fill=(255, 128, 140, 140))
    if style == "anime":
        for sx in (-1, 1):
            ex = CX + sx * (EYE_DX + 10)
            for k in range(3):
                d.line((ex - 18 + k * 12, 318, ex - 24 + k * 12, 330), fill=(255, 110, 130, 200), width=5)
    if style == "cute" and not loud:
        for sx in (-1, 1):
            ex = CX + sx * EYE_DX
            d.arc((ex - 40, EYE_Y - 74, ex + 40, EYE_Y - 20), start=200, end=340, fill=ink, width=14)
    if style == "cute" and loud:
        for sx in (-1, 1):
            ex = CX + sx * EYE_DX
            d.line((ex - sx * 40, EYE_Y - 58, ex + sx * 34, EYE_Y - 30), fill=ink, width=20)


# ---- nose ------------------------------------------------------------------

def nose(d, r, style, skin, ow, ink):
    kind = r["nose"]
    dark = rgba(shade(skin, 0.7))
    w = max(4, ow // 2)
    if kind == "muzzle":
        d.ellipse((CX - 96, 290, CX + 96, 400), fill=rgba(shade(skin, 1.25)), outline=ink, width=ow)
        for sx in (-1, 1):
            d.ellipse((CX + sx * 44 - 14, 318, CX + sx * 44 + 14, 342), fill=INK)
        d.arc((CX - 40, 330, CX + 40, 400), start=20, end=160, fill=GOLD, width=10)
    elif kind == "long":
        d.polygon([(CX - 12, 270), (CX + 30, 340), (CX - 20, 344)], fill=rgba(shade(skin, 0.9)), outline=ink, width=w)
    elif kind == "big":
        d.ellipse((CX - 34, 290, CX + 34, 346), fill=(232, 130, 110, 255), outline=ink, width=w)
    elif kind == "round":
        d.ellipse((CX - 30, 292, CX + 30, 340), fill=rgba(shade(skin, 0.92)), outline=ink, width=w)
    elif kind == "hollow":
        d.polygon([(CX - 14, 300), (CX + 14, 300), (CX, 326)], fill=INK)
    elif kind == "flat":
        d.line((CX - 20, 318, CX + 20, 318), fill=dark, width=w + 4)
    else:
        if style == "anime":
            d.line((CX + 4, 300, CX - 4, 316), fill=dark, width=4)
        else:
            d.arc((CX - 16, 290, CX + 16, 326), start=20, end=160, fill=dark, width=w)


# ---- mouth -----------------------------------------------------------------

MOUTH_Y = 380


def note(d, x, y, scale=1.0):
    rr = 20 * scale
    sx = x + rr * 1.1
    top = y - 82 * scale
    for color, grow in ((INK, 7), (WHITE, 0)):
        d.ellipse((x - rr * 1.3 - grow, y - rr - grow, x + rr * 1.3 + grow, y + rr + grow), fill=color)
        d.line((sx, y, sx, top), fill=color, width=int(10 * scale) + grow * 2)
        d.line((sx, top, sx + 34 * scale, top + 26 * scale), fill=color, width=int(10 * scale) + grow * 2)


def mouth(d, r, style, loud, skin, ow, ink):
    my = MOUTH_Y + (12 if r["nose"] == "muzzle" else 0)
    if r.get("beard"):
        bc = rgba(r["beard"])
        d.polygon([(CX - 132, 320), (CX + 132, 320), (CX + 110, 450), (CX + 40, 500), (CX - 40, 500),
                   (CX - 110, 450)], fill=bc, outline=ink, width=ow)
        d.polygon([(CX - 70, 312), (CX, 300), (CX + 70, 312), (CX + 60, 336), (CX - 60, 336)], fill=bc)
    if loud:
        if style == "anime":
            d.polygon([(CX - 56, my - 26), (CX + 56, my - 26), (CX, my + 50)], fill=MOUTH, outline=ink, width=6)
            d.ellipse((CX - 26, my + 4, CX + 26, my + 40), fill=TONGUE)
        else:
            d.ellipse((CX - 84, my - 70, CX + 84, my + 66), fill=MOUTH, outline=ink, width=max(6, ow))
            d.ellipse((CX - 44, my + 6, CX + 44, my + 60), fill=TONGUE)
            if style == "epic":
                # Bared teeth top and bottom, fangs at the corners.
                teeth = (240, 234, 214, 255)
                d.chord((CX - 70, my - 66, CX + 70, my - 30), start=180, end=360, fill=teeth)
                d.chord((CX - 60, my + 40, CX + 60, my + 64), start=0, end=180, fill=teeth)
                for sx in (-1, 1):
                    d.polygon([(CX + sx * 54, my - 52), (CX + sx * 44, my - 14), (CX + sx * 34, my - 50)], fill=teeth)
    else:
        if style == "cute":
            d.ellipse((CX + 4, my - 30, CX + 56, my + 20), fill=rgba(shade(skin, 0.8)), outline=ink, width=10)
            d.ellipse((CX + 22, my - 14, CX + 40, my + 6), fill=MOUTH)
        elif style == "anime":
            d.arc((CX - 30, my - 40, CX + 30, my + 4), start=30, end=150, fill=ink, width=7)
        else:
            d.line((CX - 50, my - 4, CX + 50, my - 8), fill=ink, width=10)
    # Tusks and undead jaw.
    t = r.get("tusks")
    if t == "small":
        for sx in (-1, 1):
            bx = CX + sx * (76 if loud else 60)
            d.polygon([(bx - 14, my + 10), (bx, my - (64 if loud else 46)), (bx + 14, my + 8)],
                      fill=TUSK, outline=ink, width=max(4, ow // 2))
    elif t == "big":
        for sx in (-1, 1):
            bx = CX + sx * 104
            d.polygon([(bx - sx * 6, my + 30), (bx + sx * 44, my - 96), (bx + sx * 26, my - 100),
                       (bx - sx * 26, my + 14)], fill=TUSK, outline=ink, width=max(4, ow // 2))
    if r.get("undead"):
        d.rectangle((CX + 60, my - 4, CX + 120, my + 26), fill=(230, 226, 210, 255), outline=ink, width=4)
        for k in range(4):
            d.line((CX + 64 + k * 15, my - 4, CX + 64 + k * 15, my + 26), fill=ink, width=3)
        d.line((CX - 120, 250, CX - 90, 300), fill=(90, 60, 70, 255), width=5)
        d.line((CX - 112, 268, CX - 98, 262), fill=(90, 60, 70, 255), width=4)
        d.line((CX - 104, 284, CX - 90, 278), fill=(90, 60, 70, 255), width=4)


# ----------------------------------------------------------------------------
# Backgrounds
# ----------------------------------------------------------------------------

def radial(inner, outer):
    g = Image.radial_gradient("L").resize((S, S))
    a = Image.new("RGBA", (S, S), rgba(inner))
    b = Image.new("RGBA", (S, S), rgba(outer))
    return Image.composite(b, a, g)


def background(r, style, loud):
    if style == "cute":
        bg = Image.new("RGBA", (S, S), rgba((210, 48, 48) if loud else (52, 168, 90)))
    elif style == "anime":
        bg = radial((255, 200, 120), (255, 110, 60)) if loud else radial((255, 236, 246), (170, 200, 255))
        d = ImageDraw.Draw(bg)
        if loud:
            for k in range(28):
                a = k * math.tau / 28
                d.line((CX + math.cos(a) * 150, 256 + math.sin(a) * 150, CX + math.cos(a) * 260,
                        256 + math.sin(a) * 260), fill=(255, 255, 255, 200), width=6)
        else:
            for x, y, s in ((92, 120, 22), (420, 150, 16), (110, 400, 14), (430, 410, 20)):
                d.polygon([(x, y - s), (x + s / 4, y), (x, y + s), (x - s / 4, y)], fill=WHITE)
                d.polygon([(x - s, y), (x, y + s / 4), (x + s, y), (x, y - s / 4)], fill=WHITE)
    else:  # epic
        lit, dark = FACTION_COLORS[r["faction"]]
        bg = radial(lit, dark)
        if loud:
            d = ImageDraw.Draw(bg)
            for k in range(16):
                a = k * math.tau / 16 + 0.1
                w = 0.09
                d.polygon([(CX, 300), (CX + math.cos(a - w) * 400, 300 + math.sin(a - w) * 400),
                           (CX + math.cos(a + w) * 400, 300 + math.sin(a + w) * 400)], fill=(255, 140, 40, 90))
            for k in range(40):
                x = (k * 97) % S
                y = (k * 53) % S
                d.ellipse((x, y, x + 6, y + 6), fill=(255, 200, 90, 220))
    return bg


def epic_lighting(face):
    """Dark on one side, a warm rim on the other, clipped to the face."""
    alpha = face.split()[3]
    grad = Image.linear_gradient("L").rotate(90).resize((S, S))  # dark on the left
    dark = Image.new("RGBA", (S, S), (0, 0, 10, 255))
    dark.putalpha(Image.eval(grad, lambda v: int(v * 0.55)))
    lit = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    lit.paste(dark, (0, 0), Image.composite(dark.split()[3], Image.new("L", (S, S), 0), alpha))
    out = face.copy()
    out.alpha_composite(lit)
    rim = alpha.filter(ImageFilter.MaxFilter(9))
    rim_layer = Image.new("RGBA", (S, S), (255, 190, 110, 0))
    rim_layer.putalpha(Image.eval(Image.composite(rim, Image.new("L", (S, S), 0), Image.eval(alpha, lambda v: 255 - v)),
                                  lambda v: int(v * 0.5)))
    result = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    result.alpha_composite(rim_layer)
    result.alpha_composite(out)
    return result


# ----------------------------------------------------------------------------
# Portrait
# ----------------------------------------------------------------------------

def draw_face(r, style, loud):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ow = {"cute": 12, "anime": 7, "epic": 5}[style]
    ink = INK if style != "epic" else (16, 12, 10, 255)
    skin = r["skin"]
    if style == "epic":
        skin = shade(skin, 0.85)
    hair_back(d, r, ow, ink)
    if r.get("horns"):
        horns(d, r, ow, ink)
    ears(d, r, skin, ow, ink)
    head_shape(d, r, style, rgba(skin), ow, ink)
    markings(d, r)
    if style == "epic":
        epic_details(d, r, loud)
    hair_front(d, r, ow, ink, style)
    eyes(d, r, style, loud, ink)
    nose(d, r, style, skin, ow, ink)
    mouth(d, r, style, loud, skin, ow, ink)
    if style == "epic":
        img = epic_lighting(img)
        glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        c = r.get("eye_glow") or ((255, 120, 40) if loud else (255, 190, 90))
        for sx in (-1, 1):
            ex = CX + sx * EYE_DX
            gd.ellipse((ex - 50, EYE_Y - 30, ex + 50, EYE_Y + 30), fill=rgba(c, 190 if loud else 140))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(12)))
    return img


def epic_details(d, r, loud):
    """Shadowed brow, war paint or scars: the hard-bitten look."""
    x0, _, x1, _ = head_box(r)
    # Deep shadow across the eyes.
    for sx in (-1, 1):
        ex = CX + sx * EYE_DX
        d.ellipse((ex - 46, EYE_Y - 40, ex + 46, EYE_Y + 22), fill=(0, 0, 0, 45))
    if r["faction"] == "horde" and not r.get("undead"):
        # Three claw stripes of war paint over the left eye.
        for k in range(3):
            x = CX - 120 + k * 22
            d.line((x, EYE_Y - 70, x + 20, EYE_Y + 70), fill=(150, 20, 20, 200), width=12)
    elif r["name"] in ("Human", "Dwarf"):
        # A scar through the right brow.
        d.line((CX + 40, EYE_Y - 70, CX + 92, EYE_Y + 50), fill=(200, 110, 100, 255), width=8)
        for k in range(4):
            y = EYE_Y - 50 + k * 28
            xm = CX + 40 + (y - (EYE_Y - 70)) * 52 / 120
            d.line((xm - 12, y, xm + 12, y + 4), fill=(200, 110, 100, 255), width=4)


def portrait(race: str, style: str, loud: bool, size: int = 128, ring: bool = True) -> Image.Image:
    r = RACES[race]
    disc = Image.new("L", (S, S), 0)
    ImageDraw.Draw(disc).ellipse((8, 8, S - 8, S - 8), fill=255)

    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(background(r, style, loud), (0, 0), disc)

    face = draw_face(r, style, loud)
    whistle = style == "cute" and not loud
    placed = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if style == "epic":
        # Tight close-up: the face fills the frame.
        big = face.resize((int(S * 1.18), int(S * 1.18)), Image.LANCZOS)
        placed.alpha_composite(big, (-int(S * 0.09), -int(S * 0.02)))
    else:
        scale = 0.84
        small = face.resize((int(S * scale), int(S * scale)), Image.LANCZOS)
        off = int(S * (1 - scale) / 2)
        placed.alpha_composite(small, (off - (24 if whistle else 0), off + 14))
    if whistle:
        nd = ImageDraw.Draw(placed)
        note(nd, 374, 384, 0.85)
        note(nd, 416, 274, 0.7)
    if style == "cute" and loud:
        sd = ImageDraw.Draw(placed)
        for x0, y0, x1, y1 in ((420, 250, 488, 222), (430, 320, 500, 320), (420, 390, 488, 418),
                               (92, 250, 24, 222), (82, 320, 12, 320), (92, 390, 24, 418)):
            sd.line((x0, y0, x1, y1), fill=WHITE, width=16)
            sd.line((x0, y0, x1, y1), fill=INK, width=5)
    out.alpha_composite(Image.composite(placed, Image.new("RGBA", (S, S), (0, 0, 0, 0)), disc))

    if style == "epic":
        # Vignette: darken toward the frame.
        g = Image.radial_gradient("L").resize((S, S))
        vignette = Image.new("RGBA", (S, S), (0, 0, 0, 255))
        vignette.putalpha(Image.composite(Image.eval(g, lambda v: max(0, int((v - 120) * 1.6))),
                                          Image.new("L", (S, S), 0), disc))
        out.alpha_composite(vignette)

    if ring:
        d = ImageDraw.Draw(out)
        d.ellipse((10, 10, S - 10, S - 10), outline=GOLD_DARK, width=34)
        d.ellipse((16, 16, S - 16, S - 16), outline=GOLD, width=20)
    return out.resize((size, size), Image.LANCZOS)
