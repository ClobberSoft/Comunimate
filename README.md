# Comunimate

**Chat in World of Warcraft: Forever with just a controller, or just your voice.**

- **Split on-screen keyboard.** Each stick steers a ring over its half of the keys; L2 / R2 type. WoW-aware word suggestions (LFM, OOM, Molten Core...) that learn how you talk.
- **Talk instead of typing.** Hold the mic button (or any button or key you choose), speak, let go. Your words appear, ready to send. Speech recognition runs **on your PC**, nothing is sent online.
- **Pick the channel by voice.** "Say in party chat, we need a tank" goes to party. Works for say, yell, party, raid, instance, guild, general and trade.
- **A mascot that reacts.** Any race, Horde, Alliance or Skyborne, male or female, in Cute, Epic or Anime style. Calm while you're quiet, shouting while you talk.
- **Full settings window** you can drive with the controller: remap every button, sizes, stick feel, voice options.

PlayStation, Xbox and Steam controllers are supported, with the right button icons for each.

---

## Install

1. Download **`Comunimate-Setup-<version>.exe`** from the [Releases page](https://github.com/ClobberSoft/Comunimate/releases).
2. Run it. Windows may say *"Windows protected your PC"* because the installer isn't code-signed yet. Click **More info → Run anyway**.
3. That's it. The installer:
   - adds the Comunimate helper to your tray (it starts with Windows and sleeps until WoW is running)
   - finds WoW: Forever and installs the add-on for you
   - downloads the voice model once (about 500 MB)

Then start WoW. If it's already running, type `/reload`.

No admin rights needed. Uninstall from Windows Settings → Apps.

## Use it

| Do this | Get this |
|---|---|
| **L1 + R1 + D-Down** | The full keyboard |
| **Hold the mic button**, talk, let go | A small "Listening to your wisdom..." box with your words, ready to send |
| **Click your mascot** | Settings |
| `/cm` / `/cm options` | Keyboard / settings |

On the keyboard (PlayStation names, all remappable):

| Button | Does |
|---|---|
| Left / right stick | Move the ring over that half of the keys |
| L2 / R2 | Type the key under the left / right ring |
| Cross | Space |
| Square | Delete (hold to repeat) |
| Triangle | Use the highlighted word suggestion |
| D-Left / D-Right | Pick a suggestion |
| L1 | Shift · D-Up: Caps lock · R1: numbers and symbols |
| D-Down | Channel (Auto, Party, Raid, Instance, Guild, Say, Yell, General, Trade) |
| Options | Send |
| Circle | Close |

### Voice tips

- Start with the channel: *"Say in raid chat, pull in five"* → `/ra Pull in five`, or *"Whisper Thrall, are you coming?"*
- Keyboard players: set a **talk key** (F9, a mouse side button...) in Settings → Voice.
- Right-click the orc in your system tray for the microphone, auto-send, and other options.

### Good to know

- WoW doesn't let add-ons send chat during boss fights and Mythic+. Your message is kept, so send it afterwards.
- The helper only listens while you hold the talk button, and only types into WoW when WoW is the window in front.

---

## For developers

```
Comunimate/         the WoW add-on (Lua). Copy this folder to Interface\AddOns to use it alone.
ComunimateVoice/    the Windows helper: tray app, speech-to-text, controller, installer build
tools/              icon, banner and mascot art pipelines
art/                art guide, banner source, mascot roster (source PNGs)
```

**Setup** (Windows, Python 3.12):

```powershell
powershell -ExecutionPolicy Bypass -File ComunimateVoice\setup.ps1
```

**Build the installer** (needs [Inno Setup 6](https://jrsoftware.org/isinfo.php)):

```powershell
powershell -ExecutionPolicy Bypass -File ComunimateVoice\build.ps1
```

The version comes from `## Version:` in `Comunimate/Comunimate.toc`. Output: `release/Comunimate-Setup-<version>.exe`.

**Art:** see [art/ART_GUIDE.md](art/ART_GUIDE.md). New mascot pictures go through `tools/mascot_art.py import <folder>`, and a new banner through `tools/make_header.py`.

## License

Code: MIT. Artwork: © ClobberSoft, for use with Comunimate. See [LICENSE](LICENSE).

Comunimate is a fan project and is not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft is a trademark of Blizzard Entertainment, Inc.
