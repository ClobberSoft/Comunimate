# Building From Source

## Layout

```
Comunimate/         the WoW add-on (Lua). Copy to Interface\AddOns to run it alone.
ComunimateVoice/    the Windows helper: tray app, speech-to-text, controller input, installer
tools/              art, icon, banner and word-list pipelines; swipe tests
art/                art guide, banner source, mascot roster (source PNGs)
docs/wiki/          this wiki
```

## Requirements

- Windows 10/11
- Python 3.12
- [Inno Setup 6](https://jrsoftware.org/isinfo.php) (for the installer)

## Setup

```powershell
powershell -ExecutionPolicy Bypass -File ComunimateVoice\setup.ps1
```

Creates `ComunimateVoice\.venv` and installs everything in `requirements.txt`.

## Build the installer

```powershell
powershell -ExecutionPolicy Bypass -File ComunimateVoice\build.ps1
```

- Bundles the helper (PyInstaller) together with the add-on, then wraps it with Inno Setup.
- The version comes from `## Version:` in `Comunimate/Comunimate.toc`.
- Output: `release/Comunimate-Setup-<version>.exe`.
- Build files go to `%LOCALAPPDATA%\ComunimateBuild`, outside OneDrive.

## Run the helper without installing

```powershell
ComunimateVoice\.venv\Scripts\python.exe ComunimateVoice\helper.py
```

`comunimate_voice.py --buttons` prints controller button numbers; `--mics` lists microphones.

## Tools

| Script | Does |
|---|---|
| `tools/make_icons.py` | Controller button icons, ring, trail glow, gold frame |
| `tools/mascot_art.py import <folder>` | Mascot PNGs → `Comunimate/Media/Mascots/*.tga` |
| `tools/make_header.py` | Settings banner from `art/header/header_source.*` |
| `tools/make_words.py` | `Comunimate/Words.lua` from wordfreq |
| `tools/test_swipe.py` | Runs `Swipe.lua` against simulated stick traces and reports accuracy |

## How the pieces talk

- The add-on can't access the microphone, so the **helper** does voice. It reads the controller (SDL) and the talk key, records while you hold it, transcribes locally (faster-whisper), and types the text into WoW (SendInput).
- To tell the add-on when you start and stop talking, the helper taps hidden key combos (Ctrl+Shift+F10 / F11) that the add-on binds temporarily.
- The helper reads your talk button and key choice from the add-on's saved variables, which WoW writes on `/reload` or logout.
- Messages are sent from the add-on's own text box through a **secure macro button**, which works for Say/Yell outdoors and during chat lockdown, with the chat API as a fallback. The add-on never touches Blizzard's chat box, so it can't taint it.

## Releasing

1. Bump `## Version:` in `Comunimate/Comunimate.toc` (and `VERSION` in `ComunimateVoice/helper.py`).
2. Build the installer.
3. Zip the `Comunimate` folder as `Comunimate-addon-<version>.zip`.
4. Create a GitHub release with both files and the changelog entry.
