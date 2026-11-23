"""Mascot art: export reference pictures, and import finished art into the add-on.

    python tools/mascot_art.py export            -> art/reference/*.png (512 px)
    python tools/mascot_art.py import [folder]   -> folder (default art/custom) into Comunimate/Media/Mascots

Picture names:  <race>_<gender>_<style>_<mood>.png   e.g. orc_female_epic_loud.png
  race    orc troll tauren undead human dwarf nightelf gnome skyborne
  gender  male female
  style   cute epic anime
  mood    quiet (mic off) or loud (talking)

Pictures that already have see-through corners (cut into a circle) are used as
they are. Square pictures are cut into a circle. The gold frame is a separate
layer in the game (Settings > Badge > Gold frame), so it's never baked in.

Run with the voice app's Python:
    ComunimateVoice\\.venv\\Scripts\\python.exe tools\\mascot_art.py import art\\custom
"""
from __future__ import annotations

import re
import struct
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "ComunimateVoice"))
import portraits  # noqa: E402

REFERENCE = ROOT / "art" / "reference"
CUSTOM = ROOT / "art" / "custom"
MASCOTS = ROOT / "Comunimate" / "Media" / "Mascots"
SIZE = 256  # in-game texture size (sharp even on a big badge)
GENDERS = ("male", "female")
NAME = re.compile(r"^(?P<race>[a-z]+)_(?P<gender>male|female)_(?P<style>[a-z]+)_(?P<mood>quiet|loud)$")


def write_tga(img: Image.Image, path: Path) -> None:
    """Uncompressed 32-bit TGA, bottom-left origin (what WoW reads)."""
    img = img.convert("RGBA").transpose(Image.FLIP_TOP_BOTTOM)
    w, h = img.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    r, g, b, a = img.split()
    path.write_bytes(header + Image.merge("RGBA", (b, g, r, a)).tobytes())


def export() -> None:
    REFERENCE.mkdir(parents=True, exist_ok=True)
    n = 0
    for race in portraits.ORDER:
        for style in portraits.STYLES:
            for loud in (False, True):
                mood = "loud" if loud else "quiet"
                portraits.portrait(race, style, loud, 512, ring=False).save(REFERENCE / f"{race}_{style}_{mood}.png")
                n += 1
    print(f"exported {n} reference pictures to {REFERENCE}")


def square(img: Image.Image) -> Image.Image:
    w, h = img.size
    side = min(w, h)
    return img.convert("RGBA").crop(((w - side) // 2, (h - side) // 2, (w + side) // 2, (h + side) // 2))


def already_round(img: Image.Image) -> bool:
    """True when the corners are see-through (the picture is already a circle)."""
    a = img.split()[3]
    w, h = img.size
    corners = [a.getpixel((2, 2)), a.getpixel((w - 3, 2)), a.getpixel((2, h - 3)), a.getpixel((w - 3, h - 3))]
    return max(corners) < 16


def to_circle(img: Image.Image) -> Image.Image:
    S = img.size[0]
    disc = Image.new("L", (S, S), 0)
    ImageDraw.Draw(disc).ellipse((1, 1, S - 2, S - 2), fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(img, (0, 0), disc)
    return out


def import_art(folder: Path) -> None:
    files = sorted(p for p in folder.iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"))
    if not files:
        print(f"no pictures in {folder}")
        return
    MASCOTS.mkdir(parents=True, exist_ok=True)
    done, skipped = set(), []
    for p in files:
        m = NAME.match(p.stem.lower())
        if not m or m["race"] not in portraits.RACES or m["style"] not in portraits.STYLES:
            skipped.append(p.name)
            continue
        img = square(Image.open(p))
        if not already_round(img):
            img = to_circle(img)
        name = f"{m['race']}_{m['gender']}_{m['style']}_{m['mood']}"
        write_tga(img.resize((SIZE, SIZE), Image.LANCZOS), MASCOTS / f"{name}.tga")
        done.add(name)
    print(f"imported {len(done)} pictures into {MASCOTS}")

    # Which combinations are still missing (the add-on falls back to the other gender).
    missing = [f"{r}_{g}_{s}_{m}" for r in portraits.ORDER for g in GENDERS for s in portraits.STYLES
               for m in ("quiet", "loud") if not (MASCOTS / f"{r}_{g}_{s}_{m}.tga").exists()]
    if missing:
        print(f"{len(missing)} still missing, e.g. " + ", ".join(missing[:6]))
    else:
        print("full roster present (9 races x 2 genders x 3 styles x 2 moods)")
    if skipped:
        print("skipped (name not recognised): " + ", ".join(skipped))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "export":
        export()
    elif cmd == "import":
        import_art(Path(sys.argv[2]) if len(sys.argv) > 2 else CUSTOM)
    else:
        print(__doc__)
