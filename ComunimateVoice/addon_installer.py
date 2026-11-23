"""Find World of Warcraft installs and put the Comunimate add-on in them.

Looks in three places:
  * the folder of a running WoW (most reliable, works for any install location)
  * Battle.net's install database (C:\\ProgramData\\Battle.net\\Agent\\product.db)
  * the usual default folders
"""
from __future__ import annotations

import os
import re
import shutil
import sys
from pathlib import Path

ADDON_NAME = "Comunimate"
# Game flavour folders the add-on is made for (Forever = "_forever_").
FLAVORS = ("_forever_",)
PRODUCT_DB = Path(os.environ.get("PROGRAMDATA", r"C:\ProgramData")) / "Battle.net" / "Agent" / "product.db"
DEFAULT_ROOTS = [
    Path(r"C:\Program Files (x86)\World of Warcraft"),
    Path(r"C:\Program Files\World of Warcraft"),
]


def bundled_addon_dir() -> Path:
    """The add-on folder shipped with this app."""
    if getattr(sys, "frozen", False):
        return Path(sys._MEIPASS) / ADDON_NAME  # type: ignore[attr-defined]
    return Path(__file__).resolve().parent.parent / ADDON_NAME


def addon_version(folder: Path) -> str | None:
    toc = folder / f"{ADDON_NAME}.toc"
    try:
        for line in toc.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("## Version:"):
                return line.split(":", 1)[1].strip()
    except OSError:
        return None
    return None


def _roots_from_product_db() -> list[Path]:
    try:
        data = PRODUCT_DB.read_bytes()
    except OSError:
        return []
    text = data.decode("latin-1")
    found = re.findall(r"[A-Za-z]:[\\/][ -~]{0,200}?World of Warcraft", text)
    return [Path(p) for p in dict.fromkeys(found)]


def find_flavor_dirs(game_exes: list[str] | None = None) -> list[Path]:
    """All '_forever_'-style folders we can find."""
    flavor_dirs: dict[str, Path] = {}

    for exe in game_exes or []:
        folder = Path(exe).parent
        if folder.name in FLAVORS:
            flavor_dirs[str(folder).lower()] = folder

    for root in _roots_from_product_db() + DEFAULT_ROOTS:
        for flavor in FLAVORS:
            folder = root / flavor
            if folder.is_dir():
                flavor_dirs[str(folder).lower()] = folder

    return list(flavor_dirs.values())


def _remove_stale(source: Path, target: Path) -> None:
    """Delete files in our add-on folder that the new version no longer has."""
    if target.name != ADDON_NAME:
        return  # only ever inside Interface\AddOns\Comunimate
    for path in sorted(target.rglob("*"), reverse=True):
        rel = path.relative_to(target)
        if path.is_file() and not (source / rel).exists():
            path.unlink()
        elif path.is_dir() and not (source / rel).exists() and not any(path.iterdir()):
            path.rmdir()


def install(game_exes: list[str] | None = None, force: bool = False) -> list[tuple[Path, str]]:
    """Install or update the add-on in every Forever folder found.

    Returns [(addon folder, "installed" | "updated" | "current" | "failed: ...")].
    """
    source = bundled_addon_dir()
    new_version = addon_version(source)
    results = []
    for flavor in find_flavor_dirs(game_exes):
        target = flavor / "Interface" / "AddOns" / ADDON_NAME
        old_version = addon_version(target)
        if old_version == new_version and not force:
            results.append((target, "current"))
            continue
        try:
            target.mkdir(parents=True, exist_ok=True)
            shutil.copytree(source, target, dirs_exist_ok=True)
            _remove_stale(source, target)
            results.append((target, "updated" if old_version else "installed"))
        except OSError as e:
            results.append((target, f"failed: {e}"))
    return results


if __name__ == "__main__":
    for path, status in install(force="--force" in sys.argv):
        print(f"{status:10s} {path}")
