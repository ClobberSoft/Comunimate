# Installation

## The easy way (recommended)

1. Go to the [Releases page](https://github.com/ClobberSoft/Comunimate/releases) and download **`Comunimate-Setup-<version>.exe`**.
2. Run it.
   - Windows may show **"Windows protected your PC"**. The installer isn't code-signed yet; click **More info → Run anyway**.
   - No administrator rights are needed.
3. Done. The installer:
   - puts the **Comunimate helper** in your system tray (the orc by the clock) and starts it with Windows
   - **finds WoW: Forever** on its own and installs the add-on into `_forever_\Interface\AddOns\Comunimate`
   - downloads the **voice model once** in the background (about 500 MB). A notification tells you when it's ready.

Start WoW. If WoW was already running, type `/reload`.

The helper **sleeps until WoW is running**, then turns voice on. When WoW closes it lets go of the microphone and memory again.

### Updating

Download the newer installer and run it. Your settings, learned words and mascot choice are kept. The add-on in WoW is updated automatically. Type `/reload` if WoW was open.

### Uninstalling

Windows Settings → Apps → **Comunimate** → Uninstall. To remove the add-on too, delete `Interface\AddOns\Comunimate` from your WoW folder.

## Add-on only (no voice)

If you only want the controller keyboard:

1. Download **`Comunimate-addon-<version>.zip`** from the [Releases page](https://github.com/ClobberSoft/Comunimate/releases).
2. Unzip it so you have `World of Warcraft\_forever_\Interface\AddOns\Comunimate\Comunimate.toc`.
3. Start WoW and make sure Comunimate is ticked in the AddOns list on the character screen.

Everything except voice works without the helper.

## Where things live

| What | Where |
|---|---|
| The helper program | `%LOCALAPPDATA%\Programs\Comunimate` |
| Helper settings (`config.json`) | `%APPDATA%\Comunimate` |
| Helper log (`voice.log`) | `%LOCALAPPDATA%\Comunimate` |
| Voice model | your user's Hugging Face cache (`%USERPROFILE%\.cache\huggingface`) |
| The add-on | `World of Warcraft\_forever_\Interface\AddOns\Comunimate` |
| In-game settings | WoW's own saved variables (`WTF\Account\...\SavedVariables\Comunimate.lua`) |
