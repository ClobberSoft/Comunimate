"""Comunimate Voice engine: hold a controller button, talk, and your words are typed into WoW chat.

Speech recognition runs on this PC (faster-whisper). Nothing is sent online
after the one-time model download.

Normally this runs inside the tray helper (helper.py). For testing it also runs
on its own in a console:

    python comunimate_voice.py               run it
    python comunimate_voice.py --buttons     show controller button names as you press them
    python comunimate_voice.py --mics        list microphones
"""
from __future__ import annotations

import argparse
import collections
import gc
import json
import os
import queue
import re
import sys
import threading
import time
from pathlib import Path
from typing import Callable

# Must be set before pygame loads SDL.
os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
# Keep reading the controller while WoW (not this program) is in front.
os.environ.setdefault("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1")
# Leave the PS5 lights alone (WoW colors them by faction).
os.environ.setdefault("SDL_JOYSTICK_HIDAPI_PS5_PLAYER_LED", "0")
# Windows without Developer Mode can't make symlinks; the model cache works anyway.
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")

import numpy as np
import sounddevice as sd

import wininput

HERE = Path(__file__).resolve().parent
# Settings and logs live in the user's profile so updates never overwrite them.
APP_DIR = Path(os.environ.get("APPDATA") or HERE) / "Comunimate"
DATA_DIR = Path(os.environ.get("LOCALAPPDATA") or HERE) / "Comunimate"
CONFIG_PATH = APP_DIR / "config.json"
LOG_PATH = DATA_DIR / "voice.log"
# Default settings shipped with the app (copied to CONFIG_PATH on first run).
BUNDLED_CONFIG = (Path(getattr(sys, "_MEIPASS", HERE)) if getattr(sys, "frozen", False) else HERE) / "config.json"
SAMPLE_RATE = 16000

DEFAULT_CONFIG = {
    "push_to_talk_button": "mic",
    "model": "small.en",
    "device": "cpu",
    "compute_type": "int8",
    "language": "en",
    "microphone": None,
    "game_processes": ["wow.exe", "wowclassic.exe", "wowb.exe", "wowt.exe", "wowforever.exe"],
    "only_when_game_focused": True,
    "auto_send": False,
    "add_trailing_space": True,
    "strip_trailing_period": True,
    "beep": True,
    "rumble": False,
    "max_chars": 255,
    # WoW doesn't pass the PS5 mic button to add-ons when the keyboard is closed,
    # so we tell the add-on with key combos it listens for (opens chat + "Listening...").
    "signal_addon": True,
    "signal_start_key": "CTRL-SHIFT-F10",
    "signal_stop_key": "CTRL-SHIFT-F11",
    "vocabulary": "",
    "replacements": {},
}

# SDL GameController button numbers. Names cover PlayStation, Xbox and Steam.
BUTTONS = {
    "cross": 0, "a": 0,
    "circle": 1, "b": 1,
    "square": 2, "x": 2,
    "triangle": 3, "y": 3,
    "create": 4, "share": 4, "back": 4, "view": 4, "select": 4,
    "ps": 5, "guide": 5, "home": 5, "steam": 5, "xbox": 5,
    "options": 6, "start": 6, "menu": 6,
    "l3": 7, "ls": 7, "r3": 8, "rs": 8,
    "l1": 9, "lb": 9, "r1": 10, "rb": 10,
    "dpad_up": 11, "dpad_down": 12, "dpad_left": 13, "dpad_right": 14,
    "mic": 15, "misc": 15,
    "paddle1": 16, "r4": 16, "paddle2": 17, "l4": 17,
    "paddle3": 18, "r5": 18, "paddle4": 19, "l5": 19,
    "touchpad": 20,
}
# WoW's controller button names (as the add-on saves them) -> SDL button numbers.
WOW_PAD_SDL = {
    "PAD1": 0, "PAD2": 1, "PAD3": 2, "PAD4": 3,
    "PADBACK": 4, "PADSYSTEM": 5, "PADFORWARD": 6,
    "PADLSTICK": 7, "PADRSTICK": 8, "PADLSHOULDER": 9, "PADRSHOULDER": 10,
    "PADDUP": 11, "PADDDOWN": 12, "PADDLEFT": 13, "PADDRIGHT": 14,
    "PAD5": 15, "PADSOCIAL": 15,
    "PADPADDLE1": 16, "PADPADDLE2": 17, "PADPADDLE3": 18, "PADPADDLE4": 19,
    "PAD6": 20,
}

BUTTON_NAMES = {
    0: "cross / A", 1: "circle / B", 2: "square / X", 3: "triangle / Y",
    4: "create / view", 5: "PS / guide", 6: "options / menu", 7: "L3", 8: "R3",
    9: "L1", 10: "R1", 11: "dpad_up", 12: "dpad_down", 13: "dpad_left", 14: "dpad_right",
    15: "mic", 16: "paddle1", 17: "paddle2", 18: "paddle3", 19: "paddle4", 20: "touchpad",
}

# Things Whisper sometimes "hears" in silence or noise.
PHANTOM_PHRASES = {"you", "thank you", "thanks for watching", "bye", "thank you for watching", ""}

LOG_MAX_BYTES = 1_000_000


# ----------------------------------------------------------------------------
# Logging and settings
# ----------------------------------------------------------------------------

def log(msg: str) -> None:
    line = f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}"
    if sys.stdout:
        try:
            print(line[11:], flush=True)
        except OSError:
            pass
    try:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        if LOG_PATH.exists() and LOG_PATH.stat().st_size > LOG_MAX_BYTES:
            LOG_PATH.replace(LOG_PATH.with_suffix(".old.log"))
        with LOG_PATH.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


class ConfigError(Exception):
    pass


def load_config() -> dict:
    """Read settings, creating the settings file from the defaults on first run."""
    cfg = dict(DEFAULT_CONFIG)
    if not CONFIG_PATH.exists():
        APP_DIR.mkdir(parents=True, exist_ok=True)
        if BUNDLED_CONFIG.exists():
            CONFIG_PATH.write_bytes(BUNDLED_CONFIG.read_bytes())
    if CONFIG_PATH.exists():
        try:
            cfg.update(json.loads(CONFIG_PATH.read_text(encoding="utf-8")))
        except json.JSONDecodeError as e:
            raise ConfigError(f"{CONFIG_PATH.name} has a mistake on line {e.lineno}: {e.msg}") from e
    return cfg


def save_config(cfg: dict) -> None:
    APP_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text(json.dumps(cfg, indent=2), encoding="utf-8")


def resolve_button(value) -> int:
    if isinstance(value, int):
        return value
    key = str(value).strip().lower().replace(" ", "_").replace("-", "_")
    if key.isdigit():
        return int(key)
    if key not in BUTTONS:
        raise ConfigError(f"Unknown push_to_talk_button '{value}'. Use one of: {', '.join(sorted(BUTTONS))}")
    return BUTTONS[key]


def beep(cfg: dict, freq: int, ms: int = 60) -> None:
    if not cfg["beep"]:
        return
    import winsound
    threading.Thread(target=winsound.Beep, args=(freq, ms), daemon=True).start()


def game_in_front(cfg: dict) -> bool:
    name = wininput.foreground_process_name()
    return name in {p.lower() for p in cfg["game_processes"]}


# ----------------------------------------------------------------------------
# Microphone
# ----------------------------------------------------------------------------

class Recorder:
    """Keeps the mic open and buffers audio while the button is held.

    A short pre-roll is kept so the first word isn't clipped.
    """

    BLOCK = 1024

    def __init__(self, device, preroll_seconds: float = 0.35):
        self.lock = threading.Lock()
        self.recording = False
        self.chunks: list[np.ndarray] = []
        try:
            self.rate = SAMPLE_RATE
            self.stream = self._open(device, SAMPLE_RATE)
        except Exception:
            # Some mics refuse 16 kHz; record at their own rate and resample.
            info = sd.query_devices(device, "input")
            self.rate = int(info["default_samplerate"])
            self.stream = self._open(device, self.rate)
        blocks = max(1, int(preroll_seconds * self.rate / self.BLOCK))
        self.preroll: collections.deque = collections.deque(maxlen=blocks)
        self.stream.start()

    def _open(self, device, rate):
        return sd.InputStream(samplerate=rate, channels=1, dtype="float32",
                              blocksize=self.BLOCK, device=device, callback=self._callback)

    def _callback(self, indata, frames, time_info, status):
        block = indata[:, 0].copy()
        with self.lock:
            if self.recording:
                self.chunks.append(block)
            else:
                self.preroll.append(block)

    def start(self) -> None:
        with self.lock:
            self.chunks = list(self.preroll)
            self.recording = True

    def stop(self) -> np.ndarray:
        with self.lock:
            self.recording = False
            data, self.chunks = self.chunks, []
            self.preroll.clear()
        if not data:
            return np.zeros(0, dtype=np.float32)
        audio = np.concatenate(data)
        if self.rate != SAMPLE_RATE:
            n = int(len(audio) * SAMPLE_RATE / self.rate)
            audio = np.interp(np.linspace(0, len(audio) - 1, n), np.arange(len(audio)), audio)
        return audio.astype(np.float32)

    def close(self) -> None:
        try:
            self.stream.stop()
            self.stream.close()
        except Exception:
            pass


# ----------------------------------------------------------------------------
# Speech to text
# ----------------------------------------------------------------------------

def model_is_downloaded(cfg: dict) -> bool:
    from faster_whisper.utils import download_model
    try:
        download_model(cfg["model"], local_files_only=True)
        return True
    except Exception:
        return False


def download_model(cfg: dict) -> None:
    from faster_whisper.utils import download_model as fw_download
    fw_download(cfg["model"])


class Transcriber:
    def __init__(self, cfg: dict):
        from faster_whisper import WhisperModel
        self.cfg = cfg
        log(f"Loading speech model '{cfg['model']}'...")
        try:
            self.model = WhisperModel(cfg["model"], device=cfg["device"], compute_type=cfg["compute_type"])
        except Exception as e:
            if cfg["device"] == "cpu":
                raise
            log(f"Could not use device '{cfg['device']}' ({e}); falling back to CPU.")
            self.model = WhisperModel(cfg["model"], device="cpu", compute_type="int8")
        log("Speech model ready.")

    def transcribe(self, audio: np.ndarray) -> str:
        segments, _ = self.model.transcribe(
            audio,
            language=self.cfg["language"] or None,
            beam_size=5,
            vad_filter=True,
            condition_on_previous_text=False,
            initial_prompt=self.cfg["vocabulary"] or None,
        )
        return " ".join(s.text.strip() for s in segments).strip()


# Say the channel first: "In party, we need a tank" -> "/p We need a tank".
CHANNEL_WORDS = {
    "say": "/s ", "party": "/p ", "raid": "/ra ", "raid warning": "/rw ", "guild": "/g ",
    "instance": "/i ", "yell": "/y ", "officer": "/o ",
    "general": "/general ", "trade": "/trade ", "reply": "/r ",
}
# "In party, ...", "Say in party chat, ...", "Send to the guild channel: ...", "Say in say chat ..."
CHANNEL_RE = re.compile(
    r"^\s*(?:(?:say|send|post|speak|talk|type|yell)\s*,?\s+)?"
    r"(?:in|into|to|on)\s*(?:the\s+)?"
    r"(raid warning|say|party|raid|guild|instance|yell|officer|general|trade|reply)"
    r"(?:\s+(?:chat|channel))?\b[\s,.:;!-]*",
    re.IGNORECASE)
# "Reply, on my way" / "Reply: ..." -> whisper back to whoever whispered you last.
REPLY_RE = re.compile(r"^\s*reply\b[\s,.:;!-]*", re.IGNORECASE)
WHISPER_RE = re.compile(r"^\s*(?:whisper|tell|message)\s+(?:to\s+)?([A-Za-zÀ-ɏ]+)\b[\s,.:;!-]*",
                        re.IGNORECASE)


def apply_channel_phrase(text: str) -> str:
    """Turn a spoken channel at the start into a chat command the add-on understands."""
    def rest_of(m):
        rest = text[m.end():].strip()
        return rest[:1].upper() + rest[1:]

    m = CHANNEL_RE.match(text)
    if m:
        return CHANNEL_WORDS[m.group(1).lower()] + rest_of(m)
    m = REPLY_RE.match(text)
    if m:
        return "/r " + rest_of(m)
    m = WHISPER_RE.match(text)
    if m:
        name = m.group(1).capitalize()
        return f"/w {name} " + rest_of(m)
    return text


def clean_text(text: str, cfg: dict) -> str:
    text = " ".join(text.split())
    if re.sub(r"[^\w ]", "", text).strip().lower() in PHANTOM_PHRASES:
        return ""
    if cfg.get("channel_phrases", True):
        text = apply_channel_phrase(text)
    for spoken, written in cfg["replacements"].items():
        pattern = r"(?<![\w'])" + re.escape(spoken) + r"(?![\w'])"
        text = re.sub(pattern, written.replace("\\", "\\\\"), text, flags=re.IGNORECASE)
    if cfg["strip_trailing_period"] and text.endswith(".") and not text.endswith(".."):
        text = text[:-1]
    text = text.replace("|", "/")  # WoW treats | as a formatting code
    return text[: cfg["max_chars"]].strip()


# ----------------------------------------------------------------------------
# A voice session: mic + model + typing. Can be loaded and unloaded.
# ----------------------------------------------------------------------------

class VoiceSession:
    """Holds the speech model and mic while WoW is running.

    on_status(state) is called with "listening", "thinking" or "ready".
    """

    def __init__(self, cfg: dict, on_status: Callable[[str], None] | None = None):
        self.cfg = cfg
        self.on_status = on_status or (lambda state: None)
        self.transcriber: Transcriber | None = None
        self.recorder: Recorder | None = None
        self.jobs: queue.Queue = queue.Queue()
        self.listening = False
        threading.Thread(target=self._worker, daemon=True).start()

    @property
    def ready(self) -> bool:
        return self.transcriber is not None and self.recorder is not None

    def load(self) -> None:
        if self.transcriber is None:
            self.transcriber = Transcriber(self.cfg)
        if self.recorder is None:
            self.recorder = Recorder(self.cfg["microphone"])
            log("Microphone open.")

    def unload(self) -> None:
        if self.recorder is not None:
            self.recorder.close()
            self.recorder = None
            log("Microphone closed.")
        if self.transcriber is not None:
            self.transcriber = None
            gc.collect()
            log("Speech model unloaded.")

    def _signal(self, key_name: str) -> None:
        if self.cfg["signal_addon"] and game_in_front(self.cfg):
            try:
                wininput.tap_combo(self.cfg[key_name])
            except (OSError, ValueError) as e:
                log(f"Could not signal the add-on: {e}")

    def press(self, pad=None) -> None:
        if not self.ready or self.listening:
            return
        self.listening = True
        self.recorder.start()
        self._signal("signal_start_key")
        beep(self.cfg, 880)
        rumble(self.cfg, pad, 0.25, 70)
        self.on_status("listening")
        log(f"Listening... (in front: {wininput.foreground_process_name() or 'unknown'})")

    def release(self, pad=None) -> None:
        if not self.listening:
            return
        self.listening = False
        audio = self.recorder.stop() if self.recorder else np.zeros(0, dtype=np.float32)
        self._signal("signal_stop_key")
        beep(self.cfg, 600)
        rumble(self.cfg, pad, 0.15, 50)
        self.on_status("thinking")
        self.jobs.put(audio)

    def _worker(self) -> None:
        while True:
            audio = self.jobs.get()
            try:
                self._handle(audio)
            finally:
                self.on_status("ready")

    def _handle(self, audio: np.ndarray) -> None:
        cfg = self.cfg
        transcriber = self.transcriber
        if transcriber is None:
            return
        seconds = len(audio) / SAMPLE_RATE
        if seconds < 0.3 or float(np.sqrt(np.mean(audio ** 2))) < 0.003:
            log("Too short or too quiet, ignored.")
            return
        started = time.time()
        try:
            text = clean_text(transcriber.transcribe(audio), cfg)
        except Exception as e:
            log(f"Speech recognition failed: {e}")
            beep(cfg, 300, 150)
            return
        took = time.time() - started
        if not text:
            log(f"Heard nothing ({seconds:.1f}s of audio).")
            beep(cfg, 300, 120)
            return
        log(f'Heard: "{text}"  ({took:.1f}s)')
        if cfg["only_when_game_focused"] and not game_in_front(cfg):
            log(f"WoW is not the active window ({wininput.foreground_process_name() or 'unknown'} is), "
                "so nothing was typed.")
            beep(cfg, 300, 120)
            return
        try:
            if cfg["add_trailing_space"] and not cfg["auto_send"]:
                text += " "
            wininput.type_text(text)
            if cfg["auto_send"]:
                time.sleep(0.05)
                wininput.press_enter()
            log("Typed into WoW.")
        except OSError as e:
            log(str(e))


def rumble(cfg: dict, pad, strength: float, ms: int) -> None:
    if cfg["rumble"] and pad is not None:
        try:
            pad.rumble(strength, strength, ms)
        except Exception:
            pass


# ----------------------------------------------------------------------------
# Controller
# ----------------------------------------------------------------------------

class ControllerReader:
    """Reads controllers through SDL. Call poll() often from one thread."""

    def __init__(self):
        import pygame
        from pygame._sdl2 import controller as sdl_controller
        self.pygame = pygame
        self.sdl = sdl_controller
        # Only what's needed for controller events (no sound, no window).
        pygame.display.init()
        pygame.joystick.init()
        sdl_controller.init()
        self.pads: dict[int, object] = {}

    def poll(self) -> list[tuple[str, int, object]]:
        """Returns [("down" | "up", button, pad)] since the last call."""
        out = []
        pg = self.pygame
        for ev in pg.event.get():
            if ev.type == pg.CONTROLLERDEVICEADDED:
                try:
                    pad = self.sdl.Controller(ev.device_index)
                except Exception as e:
                    log(f"Could not open controller: {e}")
                    continue
                pid = pad.as_joystick().get_instance_id()
                if pid not in self.pads:
                    self.pads[pid] = pad
                    log(f"Controller connected: {pad.name}")
            elif ev.type == pg.CONTROLLERDEVICEREMOVED:
                if self.pads.pop(ev.instance_id, None) is not None:
                    log("Controller disconnected.")
            elif ev.type == pg.CONTROLLERBUTTONDOWN:
                out.append(("down", ev.button, self.pads.get(ev.instance_id)))
            elif ev.type == pg.CONTROLLERBUTTONUP:
                out.append(("up", ev.button, self.pads.get(ev.instance_id)))
        return out

    def discard(self) -> None:
        """Drop queued presses (e.g. from while WoW wasn't running), keep connections."""
        for _ in self.poll():
            pass

    @property
    def connected(self) -> bool:
        return bool(self.pads)


# ----------------------------------------------------------------------------
# Console mode (for testing)
# ----------------------------------------------------------------------------

def list_mics() -> None:
    # Windows lists each mic once per audio system; show only the default one.
    default_api = sd.default.hostapi
    default_in = sd.default.device[0]
    for i, d in enumerate(sd.query_devices()):
        if d["max_input_channels"] > 0 and d["hostapi"] == default_api:
            mark = "  (Windows default)" if i == default_in else ""
            print(f"{i:3d}  {d['name']}{mark}")
    print(f'\nPut the number or name in {CONFIG_PATH} as "microphone".')


def main() -> None:
    parser = argparse.ArgumentParser(description="Talk into WoW chat with a controller button.")
    parser.add_argument("--buttons", action="store_true", help="print button numbers as you press them")
    parser.add_argument("--mics", action="store_true", help="list microphones and exit")
    args = parser.parse_args()

    if args.mics:
        list_mics()
        return

    try:
        cfg = load_config()
        ptt = resolve_button(cfg["push_to_talk_button"])
    except ConfigError as e:
        sys.exit(str(e))

    pads = ControllerReader()
    if args.buttons:
        log("Press controller buttons (Ctrl+C to quit).")
        try:
            while True:
                for kind, button, _ in pads.poll():
                    if kind == "down":
                        log(f"pressed {button} ({BUTTON_NAMES.get(button, '?')})")
                time.sleep(0.01)
        except KeyboardInterrupt:
            return

    session = VoiceSession(cfg)
    session.load()
    log(f"Comunimate Voice is running. Hold '{BUTTON_NAMES.get(ptt, ptt)}' in WoW and talk. Ctrl+C to quit.")
    try:
        while True:
            for kind, button, pad in pads.poll():
                if button == ptt:
                    session.press(pad) if kind == "down" else session.release(pad)
            time.sleep(0.008)
    except KeyboardInterrupt:
        log("Bye.")


if __name__ == "__main__":
    main()
