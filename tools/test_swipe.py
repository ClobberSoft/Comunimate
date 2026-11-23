"""Test the swipe word guesser (Comunimate/Swipe.lua) with simulated stick traces.

    ComunimateVoice\\.venv\\Scripts\\python.exe tools\\test_swipe.py [--seed N] [--noise 0.15] [--verbose]

Runs the add-on's real Lua (Dictionary, Words, Suggest, Swipe) inside Python
(lupa), traces each test word like a thumb on a stick would (wobble, cutting
corners, overshoot, pauses at turns) and reports how often the right word
comes first, and how often it's in the top 4 (the suggestion bar).
"""
from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

import lupa

ROOT = Path(__file__).resolve().parent.parent
ADDON = ROOT / "Comunimate"

WORDS = """
the and you that for with have this what are not your can will just like about out when more
need tank heals healer thanks thank hello group ready pull wait sorry where going quest help
anyone dungeon mana buff guild raid party yes okay good nice great please here there they
want come time know right think today night back still really people because something
lfm brb gg inc oom ty lol wipe summon invite loot boss mage rogue warrior priest
don't can't I'm that's you're
""".split()


def load_lua():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    ns = lua.table()
    ns.learned = lua.table_from({"words": lua.table(), "bigrams": lua.table()})
    ns.db = lua.table_from({"learn": True})
    for name in ("Dictionary.lua", "Words.lua", "Suggest.lua", "Swipe.lua"):
        chunk = lua.execute("return function(src, name) return load(src, name) end")(
            (ADDON / name).read_text(encoding="utf-8"), "@" + name)
        chunk("Comunimate", ns)
    ns.Suggest.Init(ns.Suggest)
    return lua, ns


def letter_pos(ns, ch):
    p = ns.Swipe.POS[ch]
    return p.x, p.y


def trace(ns, word, rng, noise):
    """Points (key units) a stick-driven ring might follow through the word's letters."""
    letters = [c for c in word.lower() if c.isalpha()]
    stops = []
    for c in letters:
        if not stops or stops[-1] != c:
            stops.append(c)
    pts = []
    x, y = letter_pos(ns, stops[0])
    x += rng.gauss(0, noise)
    y += rng.gauss(0, noise)
    pts.append({"x": x, "y": y})
    for c in stops[1:]:
        tx, ty = letter_pos(ns, c)
        # aim a little off the key centre, like a real thumb
        tx += rng.gauss(0, noise)
        ty += rng.gauss(0, noise)
        steps = max(3, int(math.dist((x, y), (tx, ty)) / 0.12))
        bend = rng.gauss(0, noise * 0.8)  # paths curve a bit
        for s in range(1, steps + 1):
            f = s / steps
            px = x + (tx - x) * f
            py = y + (ty - y) * f + math.sin(f * math.pi) * bend
            pts.append({"x": px + rng.gauss(0, noise * 0.25), "y": py + rng.gauss(0, noise * 0.25)})
        if rng.random() < 0.5:
            pts[-1]["dwell"] = True  # paused on the letter
        x, y = tx, ty
    return pts


def to_lua(lua, pts):
    t = lua.table()
    for i, p in enumerate(pts, 1):
        t[i] = lua.table_from(p)
    return t


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--noise", type=float, default=0.15)
    ap.add_argument("--trials", type=int, default=3)
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    lua, ns = load_lua()
    rng = random.Random(args.seed)
    top1 = top4 = total = 0
    misses = []
    for word in WORDS:
        for _ in range(args.trials):
            pts = trace(ns, word, rng, args.noise)
            res = ns.Swipe.Decode(ns.Swipe, to_lua(lua, pts), 4)
            guesses = [res[i] for i in range(1, len(res) + 1)]
            low = [g.lower() for g in guesses]
            total += 1
            if low and low[0] == word.lower():
                top1 += 1
            if word.lower() in low:
                top4 += 1
            else:
                misses.append((word, guesses))
            if args.verbose:
                print(f"{word:10s} -> {guesses}")
    print(f"{total} traces, noise {args.noise}: top-1 {top1 / total:.0%}, in top-4 {top4 / total:.0%}")
    if misses:
        print("missed:", ", ".join(f"{w}->{g[:2]}" for w, g in misses[:25]))


if __name__ == "__main__":
    main()
