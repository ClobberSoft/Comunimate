# Comunimate mascot art guide

## What's here

- `roster/` holds the master copies of all 108 mascot pictures (9 races × male/female × 3 styles × quiet/talking).
- `header/` holds the settings-window banner (`header_source.webp`).
- `custom/` is where new or replacement pictures go.

## Picture format

| | |
|---|---|
| **Format** | PNG (JPG and WebP also work) |
| **Shape** | Square, at least 512×512. 1024×1024 is ideal. |
| **Framing** | Head and shoulders, face centered. Square pictures are cut into a **circle**, so keep ears, horns and hair inside the middle ~80%. Pictures that already have see-through corners are used as they are. |
| **Background** | Anything works. A simple background reads best at small size. |
| **No** | text, watermarks, or Blizzard emblems / faction crests |
| **Name** | `race_gender_style_mood.png`, for example `orc_female_epic_loud.png` |

- **Races:** `orc` `troll` `tauren` `undead` `human` `dwarf` `nightelf` `gnome` `skyborne`
- **Genders:** `male` `female`
- **Styles:** `cute` `epic` `anime`
- **Moods:** `quiet` (mic off) and `loud` (talking)

The gold frame is a separate layer in the game (Settings → Badge → Gold frame), so don't add one.

**Tip:** make each **quiet / loud pair together** (same character, same colors, same framing) so the switch while talking looks like the same hero changing expression.

## Putting them in

Put the files in `art/custom/` (or replace the ones in `art/roster/`), then:

```powershell
ComunimateVoice\.venv\Scripts\python.exe tools\mascot_art.py import art\custom
```

Bump `## Version:` in `Comunimate/Comunimate.toc` and rebuild the installer so players get the new art.

## Prompt ideas

Use the reference picture for the race and pose, and keep the art your own: don't feed in Blizzard screenshots or official art.

- **Epic, quiet:** "Painted fantasy portrait of a stern [orc] warrior, head and shoulders, centered, glowing [amber] eyes, war paint, dramatic rim lighting, dark [crimson] background, intense, highly detailed, square"
- **Epic, loud:** the same character "roaring a battle cry, mouth wide open, fangs bared, embers and fire behind, motion and energy"
- **Anime, quiet:** "Anime-style portrait of a cheerful [troll] with [red mohawk], head and shoulders, centered, happy closed eyes, soft pastel background with sparkles, clean cel shading, square"
- **Anime, loud:** the same character "shouting excitedly, big sparkling eyes, open mouth, orange background with speed lines"
- **Cute, quiet:** "Chibi cartoon [tauren] head, round shapes, thick outlines, whistling with closed happy eyes, music notes, flat green circle background, sticker style"
- **Cute, loud:** the same character "comically yelling, squeezed >< eyes, huge open mouth, flat red circle background"

Race notes: Skyborne are an elven race with pale skin, white or ice-blue hair, upswept ears, blue sky tattoos and feathers. Night Elves have violet skin, long ears and glowing silver eyes. Undead are pale, stitched, with a bony jaw and glowing yellow eyes.
