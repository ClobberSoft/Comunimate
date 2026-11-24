"""Comunimate helper: lives in the system tray and makes the mic button just work.

* Starts with Windows (set by the installer), hidden in the tray.
* Sleeps until World of Warcraft is running, then loads the speech model and
  opens the mic. When WoW closes it lets go of both again.
* Installs / updates the WoW add-on automatically.
"""
from __future__ import annotations

import ctypes
import os
import re
import sys
import threading
import time
import traceback
import webbrowser
import winreg
from ctypes import wintypes
from pathlib import Path

import wininput

import comunimate_voice as cv  # first: sets SDL options before pygame loads
import addon_installer
import orc_art

import psutil
import pystray
from PIL import Image

APP_NAME = "Comunimate"
VERSION = "0.12.3"
RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
WIKI_URL = "https://github.com/ClobberSoft/Comunimate/wiki"
KOFI_URL = "https://ko-fi.com/clobbersoft"
SCAN_SECONDS = 2.0
# Tray icon: two looks only (whistling orc on green, yelling orc on red while
# the mic is on). Other states (waiting for WoW, loading...) are in the hover text.


# ----------------------------------------------------------------------------
# Windows bits
# ----------------------------------------------------------------------------

_mutex = None


def already_running() -> bool:
    global _mutex
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateMutexW.restype = wintypes.HANDLE
    _mutex = kernel32.CreateMutexW(None, False, "Local\\ComunimateHelper")
    return ctypes.get_last_error() == 183  # ERROR_ALREADY_EXISTS


def message_box(text: str) -> None:
    ctypes.windll.user32.MessageBoxW(None, text, APP_NAME, 0x40)


def launch_command() -> str:
    if getattr(sys, "frozen", False):
        return f'"{sys.executable}"'
    pythonw = os.path.join(os.path.dirname(sys.executable), "pythonw.exe")
    return f'"{pythonw}" "{os.path.abspath(__file__)}"'


def startup_enabled() -> bool:
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY) as key:
            winreg.QueryValueEx(key, APP_NAME)
            return True
    except OSError:
        return False


def set_startup(enabled: bool) -> None:
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY, 0, winreg.KEY_SET_VALUE) as key:
        if enabled:
            winreg.SetValueEx(key, APP_NAME, 0, winreg.REG_SZ, launch_command())
        else:
            try:
                winreg.DeleteValue(key, APP_NAME)
            except OSError:
                pass


def tray_image(state: str, size: int = 64) -> Image.Image:
    """Whistling orc on green while the mic is off, yelling orc on red while it's on."""
    return orc_art.orc_image(yelling=(state == "listening"), size=size)


# ----------------------------------------------------------------------------
# The helper
# ----------------------------------------------------------------------------

class Helper:
    def __init__(self):
        self.config_problem = None
        try:
            self.cfg = cv.load_config()
            self.ptt = cv.resolve_button(self.cfg["push_to_talk_button"])
        except cv.ConfigError as e:
            self.config_problem = str(e)
            self.cfg = dict(cv.DEFAULT_CONFIG)
            self.ptt = cv.resolve_button(self.cfg["push_to_talk_button"])

        self.state = "sleeping"
        self.detail = "Waiting for World of Warcraft"
        self.quit = threading.Event()
        self.game_exes: list[str] = []
        self.game_running = False
        self.settings_mtime = None
        self.talk_vk: int | None = None
        self.talk_key_held = False
        self.announced_ready = False
        self.downloading = False
        self.session = cv.VoiceSession(self.cfg, on_status=self.on_voice_status)
        self.icon = pystray.Icon(APP_NAME, tray_image("sleeping"), self.tooltip(), menu=self.build_menu())

    # ---- tray ---------------------------------------------------------------

    def tooltip(self) -> str:
        return f"{APP_NAME}: {self.detail}"[:120]

    def set_state(self, state: str, detail: str) -> None:
        speaking_changed = (state == "listening") != (self.state == "listening")
        self.state, self.detail = state, detail
        try:
            if speaking_changed:
                self.icon.icon = tray_image(state)
            self.icon.title = self.tooltip()
            self.icon.update_menu()
        except Exception:
            pass

    def notify(self, message: str) -> None:
        cv.log(message)
        try:
            self.icon.notify(message, APP_NAME)
        except Exception:
            pass

    def build_menu(self) -> pystray.Menu:
        item = pystray.MenuItem
        return pystray.Menu(
            item(lambda _: self.detail, None, enabled=False),
            pystray.Menu.SEPARATOR,
            item("Send right after speaking", self.toggle_auto_send,
                 checked=lambda _: bool(self.cfg["auto_send"])),
            item("Start with Windows", self.toggle_startup, checked=lambda _: startup_enabled()),
            pystray.Menu.SEPARATOR,
            item("Reinstall WoW add-on", lambda: threading.Thread(
                target=self.install_addon, kwargs={"force": True}, daemon=True).start()),
            item("Open settings file", lambda: os.startfile(cv.CONFIG_PATH)),
            item("Open log", lambda: os.startfile(cv.LOG_PATH)),
            pystray.Menu.SEPARATOR,
            item("Help and wiki", lambda: webbrowser.open(WIKI_URL)),
            item("Support on Ko-fi", lambda: webbrowser.open(KOFI_URL)),
            pystray.Menu.SEPARATOR,
            item(f"Quit {APP_NAME}", self.on_quit),
        )

    def toggle_auto_send(self) -> None:
        self.cfg["auto_send"] = not self.cfg["auto_send"]
        cv.save_config(self.cfg)

    def toggle_startup(self) -> None:
        set_startup(not startup_enabled())

    def on_quit(self) -> None:
        self.quit.set()
        self.icon.stop()

    # ---- voice --------------------------------------------------------------

    def on_voice_status(self, status: str) -> None:
        if status == "listening":
            self.set_state("listening", "Listening...")
        elif status == "thinking":
            self.set_state("thinking", "Writing it down...")
        elif self.game_running and self.session.ready:
            self.set_state("ready", "Ready: hold the mic button in WoW")

    def wake(self) -> None:
        """WoW started: load the model and open the mic."""
        if self.downloading:
            return  # the download thread wakes us when done
        self.set_state("loading", "Getting voice ready...")
        try:
            self.session.load()
        except Exception as e:
            cv.log(traceback.format_exc())
            self.set_state("error", "Voice couldn't start (see log)")
            self.notify(f"Voice couldn't start: {e}")
            return
        if not self.game_running:  # WoW closed while loading
            self.session.unload()
            return
        self.set_state("ready", "Ready: hold the mic button in WoW")
        if not self.announced_ready:
            self.announced_ready = True
            self.notify("Voice is ready. In WoW, hold the mic button and talk.")

    def sleep(self) -> None:
        """WoW closed: free the mic and memory."""
        self.session.unload()
        self.set_state("sleeping", "Waiting for World of Warcraft")

    # ---- add-on + model -----------------------------------------------------

    def install_addon(self, force: bool = False, quiet: bool = False) -> None:
        results = addon_installer.install(self.game_exes, force=force)
        for path, status in results:
            cv.log(f"Add-on {status}: {path}")
        changed = [s for p, s in results if s in ("installed", "updated")]
        failed = [(p, s) for p, s in results if s.startswith("failed")]
        if changed:
            extra = " Type /reload in WoW to load it." if self.game_running else ""
            self.notify(f"WoW add-on {'installed' if 'installed' in changed else 'updated'}.{extra}")
        elif force and results and not failed:
            self.notify("WoW add-on is installed and up to date.")
        if failed:
            self.notify("Couldn't install the WoW add-on (see log). Try running WoW, then 'Reinstall WoW add-on'.")
        if not results and not quiet:
            self.notify("Couldn't find WoW: Forever yet. Start the game once and the add-on installs itself.")

    def prepare_model(self) -> None:
        if cv.model_is_downloaded(self.cfg):
            return
        self.downloading = True
        self.set_state("loading", "Downloading voice model (one time)...")
        self.notify("Setting up voice: downloading the speech model (one time, about 500 MB).")
        try:
            cv.download_model(self.cfg)
            self.notify("Voice download finished.")
        except Exception as e:
            cv.log(traceback.format_exc())
            self.set_state("error", "Voice model download failed (see log)")
            self.notify(f"Voice model download failed: {e}. It will retry next start.")
            return
        finally:
            self.downloading = False
        if self.game_running:
            self.wake()
        else:
            self.set_state("sleeping", "Waiting for World of Warcraft")

    def startup_tasks(self) -> None:
        if self.config_problem:
            self.notify(f"Settings problem, using defaults: {self.config_problem}")
        self.install_addon(quiet=False)
        self.prepare_model()

    # ---- main loop ----------------------------------------------------------

    # ---- talk button / key chosen in the game's settings ----------------------

    def saved_variables_file(self) -> Path | None:
        """The newest Comunimate.lua that WoW saved (WTF/Account/*/SavedVariables)."""
        newest = None
        for flavor in addon_installer.find_flavor_dirs(self.game_exes):
            for f in flavor.glob("WTF/Account/*/SavedVariables/Comunimate.lua"):
                if newest is None or f.stat().st_mtime > newest.stat().st_mtime:
                    newest = f
        return newest

    def read_game_settings(self) -> None:
        f = self.saved_variables_file()
        if not f:
            return
        mtime = f.stat().st_mtime
        if mtime == self.settings_mtime:
            return
        self.settings_mtime = mtime
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            return
        m = re.search(r'\["talkButton"\]\s*=\s*"([^"]+)"', text)
        if m and m.group(1) in cv.WOW_PAD_SDL:
            ptt = cv.WOW_PAD_SDL[m.group(1)]
            if ptt != self.ptt:
                self.ptt = ptt
                cv.log(f"Talk button from game settings: {m.group(1)}")
        m = re.search(r'\["talkKey"\]\s*=\s*"([^"]+)"', text)
        vk = wininput.WOW_KEY_VK.get(m.group(1)) if m else None
        if vk != self.talk_vk:
            self.talk_vk = vk
            cv.log(f"Talk key from game settings: {m.group(1) if m else 'none'}")

    def poll_talk_key(self) -> None:
        """Keyboard / mouse push-to-talk, only while WoW is in front."""
        if not self.talk_vk:
            return
        held = wininput.key_down(self.talk_vk) and cv.game_in_front(self.cfg)
        if held and not self.talk_key_held:
            self.talk_key_held = True
            self.session.press(None)
        elif not held and self.talk_key_held:
            self.talk_key_held = False
            self.session.release(None)

    def find_game(self) -> list[str]:
        names = {n.lower() for n in self.cfg["game_processes"]}
        exes = []
        for proc in psutil.process_iter(["name", "exe"]):
            name = (proc.info.get("name") or "").lower()
            if name in names:
                exes.append(proc.info.get("exe") or "")
        return exes

    def run(self) -> None:
        cv.log(f"{APP_NAME} {VERSION} started.")
        threading.Thread(target=self.icon.run, daemon=True).start()
        threading.Thread(target=self.startup_tasks, daemon=True).start()

        pads = cv.ControllerReader()
        last_scan = 0.0
        while not self.quit.is_set():
            now = time.monotonic()
            if now - last_scan >= SCAN_SECONDS:
                last_scan = now
                exes = self.find_game()
                if exes and not self.game_running:
                    cv.log("WoW started.")
                    self.game_running = True
                    self.game_exes = exes
                    pads.discard()
                    threading.Thread(target=self.install_addon, kwargs={"quiet": True}, daemon=True).start()
                    threading.Thread(target=self.wake, daemon=True).start()
                elif not exes and self.game_running:
                    cv.log("WoW closed.")
                    self.game_running = False
                    self.session.release()
                    self.sleep()

                if self.game_running:
                    self.read_game_settings()

            events = pads.poll()
            if self.game_running:
                for kind, button, pad in events:
                    if button == self.ptt:
                        if kind == "down":
                            self.session.press(pad)
                        else:
                            self.session.release(pad)
                self.poll_talk_key()
            time.sleep(0.008 if self.game_running else 0.25)

        self.session.unload()
        cv.log(f"{APP_NAME} stopped.")


def main() -> None:
    if already_running():
        return
    try:
        Helper().run()
    except Exception:
        cv.log(traceback.format_exc())
        message_box(f"{APP_NAME} stopped because of an error.\n\nDetails are in:\n{cv.LOG_PATH}")


if __name__ == "__main__":
    main()
