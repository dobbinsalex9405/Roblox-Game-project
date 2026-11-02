"""Screen-control MCP server: lets Claude see this Windows screen and use the
mouse and keyboard, while Alex has it running.

Runs in the foreground of the window start.ps1 opens and listens only on
127.0.0.1, behind a bearer token kept in ~\\.screen-control\\token.
Closing that window, or pressing Ctrl+C in it, stops it. Slamming the mouse
into a screen corner aborts the action in progress (PyAutoGUI fail-safe).

Every typing and key-press call first reads the focused field through UI
Automation and goes through guard.refusal: no password, one-time code,
CAPTCHA or payment field ever gets keys from this server.
"""

from __future__ import annotations

import ctypes
import io
import os
import sys
import time
from pathlib import Path

# Physical pixels everywhere, so screenshots and clicks agree on scaled
# displays. Must run before pyautogui and mss load.
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except (AttributeError, OSError):
    pass

import mss  # noqa: E402
import pyautogui  # noqa: E402
import uvicorn  # noqa: E402
import win32gui  # noqa: E402
from mcp.server.fastmcp import FastMCP, Image  # noqa: E402
from mcp.server.transport_security import TransportSecuritySettings  # noqa: E402
from PIL import Image as PILImage  # noqa: E402
from pywinauto.controls.hwndwrapper import HwndWrapper  # noqa: E402
from pywinauto.uia_defines import IUIA  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from guard import Focus, refusal  # noqa: E402

PORT = int(os.environ.get("SCREEN_CONTROL_PORT", "8765"))
STATE_DIR = Path.home() / ".screen-control"
TOKEN_FILE = STATE_DIR / "token"
# Longest screenshot edge sent to Claude; clicks are scaled back up.
MAX_EDGE = 1568

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.05

REFUSAL_NOTE = (
    "Never use this to type into, paste into or press keys in a password, "
    "2FA or one-time code, CAPTCHA or payment field, or on a sign-in, "
    "verification or checkout page; the server refuses those, and you must "
    "not try to get around it (for example by clicking an on-screen keyboard "
    "or a saved-password suggestion). Leave those steps to Alex."
)

mcp = FastMCP(
    "screen-control",
    instructions=(
        "Sees and controls Alex's Windows laptop screen: screenshots, mouse, "
        "keyboard and windows. Take a screenshot first; x and y in every "
        "mouse tool are pixels in the most recent screenshot. " + REFUSAL_NOTE
    ),
    log_level="WARNING",
    host="127.0.0.1",
    port=PORT,
    transport_security=TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=[f"127.0.0.1:{PORT}", f"localhost:{PORT}"],
        allowed_origins=[],
    ),
)

# Where the last screenshot came from: monitor origin and downscale factor.
_frame = {"left": 0, "top": 0, "scale": 1.0, "monitor": 1}


def log(message: str) -> None:
    print(time.strftime("%H:%M:%S"), message, flush=True)


def _monitor(index: int) -> dict:
    with mss.mss() as sct:
        monitors = sct.monitors
    if index < 1 or index >= len(monitors):
        raise ValueError(f"monitor must be 1 to {len(monitors) - 1}")
    return monitors[index]


def _to_screen(x: float, y: float) -> tuple[int, int]:
    s = _frame["scale"]
    return round(_frame["left"] + x / s), round(_frame["top"] + y / s)


def _focus() -> Focus:
    title = win32gui.GetWindowText(win32gui.GetForegroundWindow())
    try:
        el = IUIA().iuia.GetFocusedElement()
        return Focus(
            window_title=title,
            name=el.CurrentName or "",
            automation_id=el.CurrentAutomationId or "",
            class_name=el.CurrentClassName or "",
            is_password=bool(el.CurrentIsPassword),
        )
    except Exception:  # noqa: BLE001 - any UIA failure means "unknown"
        return Focus(window_title=title, readable=False)


def _check(text: str = "") -> None:
    reason = refusal(_focus(), text)
    if reason:
        log(f"REFUSED: {reason}")
        raise PermissionError(f"Refused: {reason}. {REFUSAL_NOTE}")


@mcp.tool()
def screenshot(monitor: int = 1) -> list:
    """Capture a monitor (1 is the primary). Returns the image and its size.

    Mouse coordinates in the other tools are pixels in the latest screenshot.
    """
    mon = _monitor(monitor)
    with mss.mss() as sct:
        shot = sct.grab(mon)
    img = PILImage.frombytes("RGB", shot.size, shot.bgra, "raw", "BGRX")
    scale = min(1.0, MAX_EDGE / max(img.size))
    if scale < 1.0:
        img = img.resize((round(img.width * scale), round(img.height * scale)), PILImage.LANCZOS)
    _frame.update(left=mon["left"], top=mon["top"], scale=scale, monitor=monitor)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=80)
    log(f"screenshot monitor {monitor} -> {img.width}x{img.height}")
    note = (
        f"Monitor {monitor}: {img.width}x{img.height} screenshot pixels "
        f"(screen {mon['width']}x{mon['height']}). Foreground window: "
        f"{win32gui.GetWindowText(win32gui.GetForegroundWindow())!r}"
    )
    return [Image(data=buf.getvalue(), format="jpeg"), note]


@mcp.tool()
def list_monitors() -> list[dict]:
    """List monitors with their position and size in screen pixels."""
    with mss.mss() as sct:
        return [dict(index=i, **m) for i, m in enumerate(sct.monitors) if i > 0]


@mcp.tool()
def move_mouse(x: float, y: float) -> str:
    """Move the mouse to (x, y) in the latest screenshot's pixels."""
    sx, sy = _to_screen(x, y)
    pyautogui.moveTo(sx, sy, duration=0.1)
    log(f"move to {sx},{sy}")
    return f"Mouse at screen {sx},{sy}."


@mcp.tool()
def click(x: float, y: float, button: str = "left", clicks: int = 1) -> str:
    """Click at (x, y) in the latest screenshot's pixels.

    button is left, right or middle; clicks is 1 to 3 (2 = double-click).
    """
    if button not in ("left", "right", "middle"):
        raise ValueError("button must be left, right or middle")
    if not 1 <= clicks <= 3:
        raise ValueError("clicks must be 1 to 3")
    sx, sy = _to_screen(x, y)
    pyautogui.click(sx, sy, clicks=clicks, interval=0.08, button=button)
    log(f"{button} click x{clicks} at {sx},{sy}")
    return f"Clicked {button} x{clicks} at screen {sx},{sy}."


@mcp.tool()
def drag(from_x: float, from_y: float, to_x: float, to_y: float, button: str = "left") -> str:
    """Press at (from_x, from_y), drag to (to_x, to_y) and release (screenshot pixels)."""
    if button not in ("left", "right", "middle"):
        raise ValueError("button must be left, right or middle")
    fx, fy = _to_screen(from_x, from_y)
    tx, ty = _to_screen(to_x, to_y)
    pyautogui.moveTo(fx, fy, duration=0.1)
    pyautogui.dragTo(tx, ty, duration=0.5, button=button)
    log(f"drag {fx},{fy} -> {tx},{ty}")
    return f"Dragged from screen {fx},{fy} to {tx},{ty}."


@mcp.tool()
def scroll(x: float, y: float, amount: int) -> str:
    """Scroll the wheel at (x, y): positive amount scrolls up, negative down (in notches)."""
    sx, sy = _to_screen(x, y)
    pyautogui.moveTo(sx, sy, duration=0.1)
    pyautogui.scroll(amount * 120)
    log(f"scroll {amount} at {sx},{sy}")
    return f"Scrolled {amount} at screen {sx},{sy}."


class _KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", ctypes.c_ushort),
        ("wScan", ctypes.c_ushort),
        ("dwFlags", ctypes.c_ulong),
        ("time", ctypes.c_ulong),
        ("dwExtraInfo", ctypes.c_size_t),
    ]


class _INPUT(ctypes.Structure):
    class _U(ctypes.Union):
        # MOUSEINPUT is the largest member; pad to its size.
        _fields_ = [("ki", _KEYBDINPUT), ("pad", ctypes.c_byte * 32)]

    _anonymous_ = ("u",)
    _fields_ = [("type", ctypes.c_ulong), ("u", _U)]


def _type_char(ch: str) -> None:
    """Send one character as Unicode key events, one UTF-16 unit at a time.

    Paced, because fast input drops characters in slow apps (WinUI Notepad).
    """
    data = ch.encode("utf-16-le")
    for i in range(0, len(data), 2):
        unit = int.from_bytes(data[i : i + 2], "little")
        for flags in (0x0004, 0x0004 | 0x0002):  # KEYEVENTF_UNICODE, then KEYUP
            inp = _INPUT(type=1)  # INPUT_KEYBOARD
            inp.ki = _KEYBDINPUT(0, unit, flags, 0, 0)
            ctypes.windll.user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(inp))
    time.sleep(0.02)


@mcp.tool()
def type_text(text: str) -> str:
    """Type text into the focused field. Newlines press Enter.

    Refuses password, 2FA or one-time code, CAPTCHA and payment fields, and
    sign-in, verification and checkout pages. Never try to get around it.
    """
    _check(text)
    for ch in text.replace("\r", ""):
        if ch == "\n":
            pyautogui.press("enter")
        elif ch == "\t":
            pyautogui.press("tab")
        else:
            _type_char(ch)
    log(f"typed {len(text)} characters")
    return f"Typed {len(text)} characters."


@mcp.tool()
def press_keys(keys: str) -> str:
    """Press a key or combination, such as "enter", "esc", "ctrl+s", "alt+tab".

    Names are PyAutoGUI key names joined with "+". Same refusals as type_text.
    """
    parts = [k.strip().lower() for k in keys.split("+") if k.strip()]
    unknown = [k for k in parts if k not in pyautogui.KEYBOARD_KEYS]
    if not parts or unknown:
        raise ValueError(f"unknown key name(s): {unknown or keys!r}")
    _check()
    pyautogui.hotkey(*parts)
    log(f"keys {'+'.join(parts)}")
    return f"Pressed {'+'.join(parts)}."


def _windows() -> list[tuple[int, str]]:
    found: list[tuple[int, str]] = []

    def add(hwnd, _):
        title = win32gui.GetWindowText(hwnd)
        if title and win32gui.IsWindowVisible(hwnd):
            found.append((hwnd, title))

    win32gui.EnumWindows(add, None)
    return found


@mcp.tool()
def list_windows() -> list[dict]:
    """List visible top-level windows (handle and title), foreground first."""
    fg = win32gui.GetForegroundWindow()
    wins = sorted(_windows(), key=lambda w: w[0] != fg)
    return [{"handle": h, "title": t, "foreground": h == fg} for h, t in wins]


@mcp.tool()
def focus_window(title_contains: str = "", handle: int = 0) -> str:
    """Bring a window to the front, by handle or by part of its title."""
    if handle:
        target = handle
    else:
        needle = title_contains.lower()
        matches = [h for h, t in _windows() if needle and needle in t.lower()]
        if not matches:
            raise ValueError(f"no visible window title contains {title_contains!r}")
        target = matches[0]
    HwndWrapper(target).set_focus()
    title = win32gui.GetWindowText(target)
    log(f"focus {title!r}")
    return f"Focused {title!r}."


class TokenAuth:
    """Rejects any HTTP request without the bearer token."""

    def __init__(self, app, token: str):
        self.app = app
        self.expected = f"Bearer {token}".encode()

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            headers = dict(scope.get("headers") or [])
            if headers.get(b"authorization") != self.expected:
                await send({"type": "http.response.start", "status": 401, "headers": []})
                await send({"type": "http.response.body", "body": b"unauthorized"})
                return
        await self.app(scope, receive, send)


def main() -> None:
    if not TOKEN_FILE.exists():
        sys.exit(f"No token at {TOKEN_FILE}. Start with start.ps1, which creates it.")
    token = TOKEN_FILE.read_text(encoding="utf-8").strip()
    app = TokenAuth(mcp.streamable_http_app(), token)
    log(f"screen-control listening on http://127.0.0.1:{PORT}/mcp")
    log("Claude can now see this screen and use the mouse and keyboard.")
    log("Close this window or press Ctrl+C to stop. Mouse into a corner aborts an action.")
    uvicorn.run(app, host="127.0.0.1", port=PORT, log_level="warning")


if __name__ == "__main__":
    main()
