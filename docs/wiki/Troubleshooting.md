# Troubleshooting

## The keyboard doesn't open with L1 + R1 + D-Down
- Make sure the add-on is ticked in the AddOns list on the character screen. If it says **Out of date**, tick **Load out of date AddOns**.
- Settings → General → **Controller chat button opens the keyboard** must be on.
- Type `/cm debug`, press the combo, and check chat for `chat combo caught`.
- In combat, WoW may pass the combo to its own chat box instead. Tap the talk button to open the keyboard.

## Holding the mic does nothing / "Voice helper isn't running"
- Look for the orc by the clock (it may be under the **^** arrow). If it's missing, start **Comunimate** from the Start menu.
- Hover the orc: it should say **Ready**. "Downloading voice model" means it's still setting up (first run only).
- WoW must be the window in front.
- If WoW runs **as administrator**, the helper must too, or Windows blocks it from typing.

## The mic button opens my bags
Type `/reload`. Comunimate claims the talk button when it loads. If it still happens, type `/cm debug`, press the mic, and check chat for `talk button down`.

## Words come out wrong
- Check the right microphone is used: right-click the orc → **Open settings file**, set `microphone`.
- Add names and terms to `vocabulary` in the same file.
- A bigger `model` (`medium.en`) is more accurate but slower.

## "WoW blocks add-on chat during boss fights and Mythic+"
That's WoW's rule for add-ons during encounters. Your message is kept; send it after the fight.

## The ring moves the wrong way up/down
Settings → Sticks → **Flip up and down**.

## Windows says "Windows protected your PC"
The installer isn't code-signed yet. Click **More info → Run anyway**.

## Still stuck?
[Open an issue](https://github.com/ClobberSoft/Comunimate/issues/new/choose). For voice or installer problems, include the last lines of the helper log (right-click the orc → **Open log**).
