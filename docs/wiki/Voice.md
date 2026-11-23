# Voice

Talk instead of typing. Needs the Comunimate helper (installed by the [installer](Installation); the orc in your system tray).

## Talking

1. **Hold the talk button** (the PS5 mic button by default).
   A small box appears: **"Listening to your wisdom..."**. Your mascot starts shouting.
2. **Talk**, then **let go**.
   "Writing down your wisdom..." then your words appear in the box.
3. **Send to chat** (Options) or **Cancel** (Circle). Hold the talk button again to add more. Triangle opens the full keyboard to edit.

If the full keyboard is already open, your words go straight into it.

## Picking the channel by voice

Start with the channel:

| You say | Gets sent |
|---|---|
| "Say in party chat, we need a tank" | `/p We need a tank` |
| "Say in raid chat, pull in five" | `/ra Pull in five` |
| "Say in guild chat, gz on the ding" | `/g Gz on the ding` |
| "Say in say chat, hello everyone" | `/s Hello everyone` |
| "Say in yell chat, run!" | `/y Run!` |
| "Say in general chat, anyone want to group?" | `/general Anyone want to group?` |
| "In trade, WTS linen cloth" | `/trade WTS linen cloth` |
| "Whisper Thrall, are you coming?" | `/w Thrall Are you coming?` |
| "Say in reply, on my way" | `/r On my way` (to whoever whispered you last) |
| "Reply, sure thing" | `/r Sure thing` |

The short form "In party, ..." works too. Instance and officer chat work the same way.

It also tidies WoW words: "L F M" → **LFM**, "out of mana" → **OOM**, "D P S" → **DPS**.

## Choosing your talk button or key

Settings → Voice:

- **Talk button (controller):** pick any button. Comunimate claims it, so it no longer does its normal game action (in Forever the mic button would otherwise open your bags).
- **Talk key (keyboard or mouse):** for keyboard players. F9 or a mouse side button works well. Avoid letters and Ctrl/Shift/Alt.

After changing either, type **`/reload`** once. WoW only saves settings on reload or logout, and that's when the helper reads them.

## Small box or full keyboard?

Settings → Voice → **When you talk, show:** **Small box** (default) or **Keyboard**.

## Privacy

- Speech recognition runs **on your PC** (the Whisper "small.en" model). Nothing you say is sent anywhere.
- The helper only keeps audio **while you hold the talk button**, and only types into WoW **while WoW is the window in front**.
- Windows shows the microphone in use while WoW is running, because the mic stays open so your first word isn't cut off.

## The tray icon

The orc next to your clock is the helper:

- **Whistling orc on green:** ready, not listening.
- **Yelling orc on red:** listening.
- Hover for details (waiting for WoW, getting ready...).

Right-click for: **Send right after speaking**, **Start with Windows**, **Reinstall WoW add-on**, **Open settings file**, **Open log**, **Quit**.

## Helper settings file

Right-click the orc → **Open settings file** (`config.json`). Useful entries:

| Setting | What it does |
|---|---|
| `microphone` | `null` = Windows default, or a microphone's name or number |
| `model` | `base.en` (faster), `small.en` (default), `medium.en` (most accurate, slower) |
| `device` / `compute_type` | `cuda` / `float16` to use an NVIDIA graphics card |
| `auto_send` | `true` sends right after you speak |
| `vocabulary` | Words that help recognition (names, places) |
| `replacements` | Spoken phrase → typed text, e.g. `"out of mana": "OOM"` |
| `beep` / `rumble` | Sound / controller vibration when listening starts and stops |

Quit and restart the helper (right-click → Quit, then start Comunimate from the Start menu) after editing.
