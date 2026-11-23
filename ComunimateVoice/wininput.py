"""Small Windows helpers: type text into the focused window and check which app is in front.

Uses SendInput, the same path a real keyboard uses, so WoW sees normal key presses.
"""
from __future__ import annotations

import ctypes
import os
import time
from ctypes import wintypes

user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

INPUT_MOUSE = 0
INPUT_KEYBOARD = 1
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004
VK_RETURN = 0x0D
MAPVK_VK_TO_VSC = 0
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000

ULONG_PTR = ctypes.c_size_t


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [
        ("dx", wintypes.LONG),
        ("dy", wintypes.LONG),
        ("mouseData", wintypes.DWORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ULONG_PTR),
    ]


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", wintypes.WORD),
        ("wScan", wintypes.WORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ULONG_PTR),
    ]


class HARDWAREINPUT(ctypes.Structure):
    _fields_ = [
        ("uMsg", wintypes.DWORD),
        ("wParamL", wintypes.WORD),
        ("wParamH", wintypes.WORD),
    ]


class _INPUTUNION(ctypes.Union):
    _fields_ = [("mi", MOUSEINPUT), ("ki", KEYBDINPUT), ("hi", HARDWAREINPUT)]


class INPUT(ctypes.Structure):
    _fields_ = [("type", wintypes.DWORD), ("u", _INPUTUNION)]


user32.SendInput.argtypes = (wintypes.UINT, ctypes.POINTER(INPUT), ctypes.c_int)
user32.SendInput.restype = wintypes.UINT
user32.MapVirtualKeyW.argtypes = (wintypes.UINT, wintypes.UINT)
user32.MapVirtualKeyW.restype = wintypes.UINT
user32.GetForegroundWindow.restype = wintypes.HWND
user32.GetWindowThreadProcessId.argtypes = (wintypes.HWND, ctypes.POINTER(wintypes.DWORD))
user32.GetWindowThreadProcessId.restype = wintypes.DWORD
kernel32.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
kernel32.OpenProcess.restype = wintypes.HANDLE
kernel32.QueryFullProcessImageNameW.argtypes = (
    wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD))
kernel32.QueryFullProcessImageNameW.restype = wintypes.BOOL
kernel32.CloseHandle.argtypes = (wintypes.HANDLE,)


def _send(inputs: list[INPUT]) -> None:
    arr = (INPUT * len(inputs))(*inputs)
    sent = user32.SendInput(len(inputs), arr, ctypes.sizeof(INPUT))
    if sent != len(inputs):
        raise OSError(f"SendInput sent {sent}/{len(inputs)} events (error {ctypes.get_last_error()}). "
                      "If WoW runs as administrator, run this app as administrator too.")


def _unicode_key(code_unit: int, up: bool) -> INPUT:
    flags = KEYEVENTF_UNICODE | (KEYEVENTF_KEYUP if up else 0)
    return INPUT(type=INPUT_KEYBOARD, u=_INPUTUNION(ki=KEYBDINPUT(0, code_unit, flags, 0, 0)))


def _vk_key(vk: int, up: bool) -> INPUT:
    scan = user32.MapVirtualKeyW(vk, MAPVK_VK_TO_VSC)
    flags = KEYEVENTF_KEYUP if up else 0
    return INPUT(type=INPUT_KEYBOARD, u=_INPUTUNION(ki=KEYBDINPUT(vk, scan, flags, 0, 0)))


def type_text(text: str, delay: float = 0.004) -> None:
    """Type text into whatever has keyboard focus, one character at a time."""
    data = text.encode("utf-16-le")
    for i in range(0, len(data), 2):
        unit = int.from_bytes(data[i:i + 2], "little")
        _send([_unicode_key(unit, False), _unicode_key(unit, True)])
        if delay:
            time.sleep(delay)


user32.GetAsyncKeyState.argtypes = (ctypes.c_int,)
user32.GetAsyncKeyState.restype = ctypes.c_short


def key_down(vk: int) -> bool:
    """Is this key (or mouse button) held right now?"""
    return bool(user32.GetAsyncKeyState(vk) & 0x8000)


# WoW key names (as the add-on saves them) -> Windows virtual-key codes.
WOW_KEY_VK = {
    **{f"F{i}": 0x6F + i for i in range(1, 25)},
    **{chr(c): c for c in range(ord("A"), ord("Z") + 1)},
    **{str(d): 0x30 + d for d in range(10)},
    **{f"NUMPAD{d}": 0x60 + d for d in range(10)},
    "BUTTON3": 0x04, "BUTTON4": 0x05, "BUTTON5": 0x06,
    "SPACE": 0x20, "TAB": 0x09, "CAPSLOCK": 0x14, "ENTER": 0x0D,
    "LSHIFT": 0xA0, "RSHIFT": 0xA1, "LCTRL": 0xA2, "RCTRL": 0xA3, "LALT": 0xA4, "RALT": 0xA5,
    "INSERT": 0x2D, "DELETE": 0x2E, "HOME": 0x24, "END": 0x23, "PAGEUP": 0x21, "PAGEDOWN": 0x22,
    "UP": 0x26, "DOWN": 0x28, "LEFT": 0x25, "RIGHT": 0x27,
    "`": 0xC0, "-": 0xBD, "=": 0xBB, "[": 0xDB, "]": 0xDD, "\\": 0xDC, ";": 0xBA, "'": 0xDE,
    ",": 0xBC, ".": 0xBE, "/": 0xBF,
    "NUMPADPLUS": 0x6B, "NUMPADMINUS": 0x6D, "NUMPADMULTIPLY": 0x6A, "NUMPADDIVIDE": 0x6F,
    "NUMPADDECIMAL": 0x6E, "PRINTSCREEN": 0x2C, "SCROLLLOCK": 0x91, "PAUSE": 0x13, "NUMLOCK": 0x90,
}


def press_enter() -> None:
    _send([_vk_key(VK_RETURN, False), _vk_key(VK_RETURN, True)])


_MODIFIERS = {"CTRL": 0x11, "SHIFT": 0x10, "ALT": 0x12}


def parse_combo(spec: str) -> tuple[list[int], int]:
    """'CTRL-SHIFT-F10' (WoW key binding format) -> ([modifier vks], key vk)."""
    parts = spec.upper().split("-")
    mods = [_MODIFIERS[p] for p in parts[:-1]]
    key = parts[-1]
    if key.startswith("F") and key[1:].isdigit() and 1 <= int(key[1:]) <= 24:
        vk = 0x70 + int(key[1:]) - 1
    elif len(key) == 1 and key.isalnum():
        vk = ord(key)
    else:
        raise ValueError(f"Unsupported key '{spec}'. Use something like CTRL-SHIFT-F10.")
    return mods, vk


def tap_combo(spec: str) -> None:
    """Press and release a key combo, e.g. 'CTRL-SHIFT-F10'."""
    mods, vk = parse_combo(spec)
    events = [_vk_key(m, False) for m in mods]
    events += [_vk_key(vk, False), _vk_key(vk, True)]
    events += [_vk_key(m, True) for m in reversed(mods)]
    _send(events)


def foreground_process_name() -> str:
    """File name of the program in front, lowercase (e.g. 'wow.exe'), or '' if unknown."""
    hwnd = user32.GetForegroundWindow()
    if not hwnd:
        return ""
    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid.value)
    if not handle:
        return ""
    try:
        size = wintypes.DWORD(1024)
        buf = ctypes.create_unicode_buffer(size.value)
        if kernel32.QueryFullProcessImageNameW(handle, 0, buf, ctypes.byref(size)):
            return os.path.basename(buf.value).lower()
        return ""
    finally:
        kernel32.CloseHandle(handle)
