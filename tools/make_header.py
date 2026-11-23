"""Turn art/header/header_source.* into the settings window's banner texture.

    ComunimateVoice\\.venv\\Scripts\\python.exe tools\\make_header.py

Crops the band where the characters are (the header is about 780 x 170, a
4.6 : 1 strip), and stores it in a 2048 x 512 texture (WoW wants power-of-two
sizes). The add-on shows only the filled part (Options.lua: BANNER_V).
"""
from __future__ import annotations

import struct
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "art" / "header"
OUT = ROOT / "Comunimate" / "Media" / "header.tga"

HEADER_W, HEADER_H = 780, 170  # must match Options.lua (WIN_W, HEADER_H)
CROP_TOP = 110                 # source pixels above the band (keeps the sunburst and mohawks)
TEX_W, TEX_H = 2048, 512


def write_tga(img: Image.Image, path: Path) -> None:
    img = img.convert("RGBA").transpose(Image.FLIP_TOP_BOTTOM)
    w, h = img.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    r, g, b, a = img.split()
    path.write_bytes(header + Image.merge("RGBA", (b, g, r, a)).tobytes())


def main() -> None:
    src = next(p for p in sorted(SRC_DIR.glob("header_source.*")))
    im = Image.open(src).convert("RGB")
    w, _ = im.size
    crop_h = round(w * HEADER_H / HEADER_W)
    band = im.crop((0, CROP_TOP, w, CROP_TOP + crop_h))
    band_h = round(TEX_W * HEADER_H / HEADER_W)
    band = band.resize((TEX_W, band_h), Image.LANCZOS)
    tex = Image.new("RGBA", (TEX_W, TEX_H), band.getpixel((4, 4)) + (255,))
    tex.paste(band, (0, 0))
    write_tga(tex, OUT)
    print(f"wrote {OUT.name}: band {TEX_W}x{band_h} in {TEX_W}x{TEX_H}  (BANNER_V = {band_h / TEX_H:.4f})")


if __name__ == "__main__":
    main()
