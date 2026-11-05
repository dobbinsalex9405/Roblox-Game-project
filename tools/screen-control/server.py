"""Screen-control MCP server: lets Claude see this Windows screen and use the
mouse and keyboard, while Alex has it running.

Started at logon by a Startup-folder shortcut Alex adds (pythonw, hidden,
logging to ~\\.screen-control\\server.log), or in a window by start.ps1. Listens only
on 127.0.0.1, behind a bearer token kept in ~\\.screen-control\\token, with an
unauthenticated GET /health. stop.ps1 stops it. Slamming the mouse
into a screen corner aborts the action in progress (PyAutoGUI fail-safe).

Every typing and key-press call first reads the focused field through UI
Automation and goes through guard.refusal: no password, one-time code,
CAPTCHA or payment field ever gets keys from this server. Clicks and drags
go through guard.page_refusal: none on sign-in, verification, CAPTCHA or
payment pages.
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
import win32clipboard  # noqa: E402
import win32gui  # noqa: E402
from mcp.server.fastmcp import FastMCP, Image  # noqa: E402
from mcp.server.transport_security import TransportSecuritySettings  # noqa: E402
from PIL import Image as PILImage  # noqa: E402
from pywinauto.controls.hwndwrapper import HwndWrapper  # noqa: E402
from pywinauto.uia_defines import IUIA  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from guard import Focus, covered_refusal, element_refusal, page_refusal, refusal  # noqa: E402
import overlay  # noqa: E402

PORT = int(os.environ.get("SCREEN_CONTROL_PORT", "8765"))
STATE_DIR = Path.home() / ".screen-control"
TOKEN_FILE = STATE_DIR / "token"
# Longest screenshot edge sent to Claude; clicks are scaled back up.
MAX_EDGE = 1568

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.05

REFUSAL_NOTE = (
    "Never use this to type into, paste into or press keys in a password, "
    "2FA or one-time code, CAPTCHA or payment field, or to type or click on "
    "a sign-in, verification, CAPTCHA or checkout page, or to confirm a "
    "purchase; the server refuses those, and you must "
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

CONTROL_TYPES = {
    50000: "Button",
    50002: "CheckBox",
    50003: "ComboBox",
    50004: "Edit",
    50005: "Hyperlink",
    50007: "ListItem",
    50008: "List",
    50010: "MenuBar",
    50011: "MenuItem",
    50013: "RadioButton",
    50018: "Tab",
    50019: "TabItem",
    50020: "Text",
    50024: "TreeItem",
    50030: "Document",
    50032: "Window",
    50033: "Pane",
}

# Where the last screenshot came from: monitor origin and downscale factor.
_frame = {"left": 0, "top": 0, "scale": 1.0, "monitor": 1}


def log(message: str) -> None:
    """Every action logs, so this also shows the orange "Claude is here" border."""
    print(time.strftime("%H:%M:%S"), message, flush=True)
    overlay.touch()


def _monitor(index: int) -> dict:
    with mss.mss() as sct:
        monitors = sct.monitors
    if index < 1 or index >= len(monitors):
        raise ValueError(f"monitor must be 1 to {len(monitors) - 1}")
    return monitors[index]


def _to_screen(x: float, y: float) -> tuple[int, int]:
    s = _frame["scale"]
    return round(_frame["left"] + x / s), round(_frame["top"] + y / s)


def _to_frame(sx: float, sy: float) -> tuple[int, int]:
    s = _frame["scale"]
    return round((sx - _frame["left"]) * s), round((sy - _frame["top"]) * s)


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
            framework=el.CurrentFrameworkId or "",
            control_type=CONTROL_TYPES.get(el.CurrentControlType, str(el.CurrentControlType)),
        )
    except Exception:  # noqa: BLE001 - any UIA failure means "unknown"
        return Focus(window_title=title, readable=False)


def _check(text: str, window_title_contains: str) -> None:
    """Make sure keys go to the named window and to no sensitive field.

    The Claude app tends to take the foreground between tool calls, so when
    the named window is not in front it is brought forward first; if that
    fails, nothing is sent.
    """
    if not window_title_contains:
        raise ValueError("window_title_contains is required")
    needle = window_title_contains.lower()
    focus = _focus()
    if needle not in focus.window_title.lower():
        matches = [h for h, t in _windows() if needle in t.lower()]
        if matches:
            _bring_forward(matches[0])
            time.sleep(0.4)  # let the window settle before keys arrive
            focus = _focus()
    if needle not in focus.window_title.lower():
        raise RuntimeError(
            f"Not sent: the foreground window is {focus.window_title!r}, not one whose title "
            f"contains {window_title_contains!r}, and it could not be brought to the front."
        )
    reason = refusal(focus, text)
    if reason:
        log(f"REFUSED: {reason}")
        raise PermissionError(f"Refused: {reason}. {REFUSAL_NOTE}")


def _check_click(*points: tuple[int, int]) -> None:
    """Refuse a click when the foreground window, or the window under any
    point, is a sign-in, verification, CAPTCHA or payment page."""
    titles = [win32gui.GetWindowText(win32gui.GetForegroundWindow())]
    for point in points:
        hwnd = win32gui.WindowFromPoint(point)
        if hwnd:
            titles.append(win32gui.GetWindowText(win32gui.GetAncestor(hwnd, 2)))  # GA_ROOT
    reason = page_refusal(*titles)
    if reason:
        log(f"REFUSED: {reason}")
        raise PermissionError(f"Refused: {reason}. {REFUSAL_NOTE}")


def _grab(region: dict) -> PILImage.Image:
    with mss.mss() as sct:
        shot = sct.grab(region)
    return PILImage.frombytes("RGB", shot.size, shot.bgra, "raw", "BGRX")


def _jpeg(img: PILImage.Image) -> Image:
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=80)
    return Image(data=buf.getvalue(), format="jpeg")


def _screenshot(monitor: int) -> list:
    mon = _monitor(monitor)
    img = _grab(mon)
    scale = min(1.0, MAX_EDGE / max(img.size))
    if scale < 1.0:
        img = img.resize((round(img.width * scale), round(img.height * scale)), PILImage.LANCZOS)
    _frame.update(left=mon["left"], top=mon["top"], scale=scale, monitor=monitor)
    log(f"screenshot monitor {monitor} -> {img.width}x{img.height}")
    note = (
        f"Monitor {monitor}: {img.width}x{img.height} screenshot pixels "
        f"(screen {mon['width']}x{mon['height']}, scale {scale:.3f}). Foreground window: "
        f"{win32gui.GetWindowText(win32gui.GetForegroundWindow())!r}"
    )
    return [_jpeg(img), note]


def _done(message: str, then_screenshot: bool) -> str | list:
    """A tool's result: the message, plus a fresh screenshot when asked."""
    if not then_screenshot:
        return message
    time.sleep(0.4)  # let the screen settle
    return [message, *_screenshot(_frame["monitor"])]


@mcp.tool()
def screenshot(monitor: int = 1) -> list:
    """Capture a monitor (1 is the primary). Returns the image and its size.

    Mouse coordinates in the other tools are pixels in the latest screenshot.
    """
    return _screenshot(monitor)


@mcp.tool()
def zoom(x0: float, y0: float, x1: float, y1: float) -> list:
    """Close-up of a rectangle of the latest screenshot, at full screen detail.

    Use it to read small text or find a small button. Coordinates (in and
    for later clicks) stay those of the latest full screenshot.
    """
    left, top = _to_screen(min(x0, x1), min(y0, y1))
    right, bottom = _to_screen(max(x0, x1), max(y0, y1))
    if right - left < 4 or bottom - top < 4:
        raise ValueError("the rectangle is too small")
    img = _grab({"left": left, "top": top, "width": right - left, "height": bottom - top})
    if max(img.size) > MAX_EDGE:
        k = MAX_EDGE / max(img.size)
        img = img.resize((round(img.width * k), round(img.height * k)), PILImage.LANCZOS)
    log(f"zoom {left},{top} -> {right},{bottom}")
    return [_jpeg(img), f"Zoom of screen {left},{top} to {right},{bottom}; click with full-screenshot coordinates."]


def _elements(text: str, window_title_contains: str) -> list[dict]:
    """UI Automation elements whose name contains `text`, in one window."""
    if window_title_contains:
        needle = window_title_contains.lower()
        hwnds = [h for h, t in _windows() if needle in t.lower()]
        if not hwnds:
            raise ValueError(f"no visible window title contains {window_title_contains!r}")
        hwnd = hwnds[0]
    else:
        hwnd = win32gui.GetForegroundWindow()
    iuia = IUIA().iuia
    found = iuia.ElementFromHandle(hwnd).FindAll(4, iuia.CreateTrueCondition())  # TreeScope_Descendants
    want = text.lower()
    out = []
    for i in range(found.Length):
        el = found.GetElement(i)
        name = el.CurrentName or ""
        if not name or want not in name.lower() or el.CurrentIsOffscreen:
            continue
        r = el.CurrentBoundingRectangle
        if r.right <= r.left or r.bottom <= r.top:
            continue
        x, y = _to_frame((r.left + r.right) / 2, (r.top + r.bottom) / 2)
        out.append(
            {
                "name": name,
                "type": CONTROL_TYPES.get(el.CurrentControlType, str(el.CurrentControlType)),
                "x": x,
                "y": y,
                "_screen": ((r.left + r.right) // 2, (r.top + r.bottom) // 2),
                "_hwnd": hwnd,
            }
        )
    return out


def _owner_chain(point: tuple[int, int]) -> list[int]:
    """The top-level window at a point, then its owner, its owner's owner...

    Menus and dropdowns are top-level windows owned by their app, so a click
    on them belongs to the app's window too.
    """
    h = win32gui.GetAncestor(win32gui.WindowFromPoint(point), 2)  # GA_ROOT
    chain = []
    while h and h not in chain:
        chain.append(h)
        h = win32gui.GetWindow(h, 4)  # GW_OWNER
    return chain or [0]


@mcp.tool()
def find_elements(text: str, window_title_contains: str = "") -> list[dict]:
    """Find buttons, fields, menu items... whose accessible name contains `text`.

    Searches the foreground window (or the first window whose title contains
    window_title_contains). Returns up to 30 with their centre in the latest
    screenshot's pixels. Works for native apps (Studio, file dialogs,
    Explorer); Chrome often hides page contents, so use the browser tools or
    a screenshot there.
    """
    found = _elements(text, window_title_contains)
    log(f"find {text!r}: {len(found)}")
    return [{k: v for k, v in e.items() if not k.startswith("_")} for e in found[:30]]


@mcp.tool(structured_output=False)
def click_element(text: str, window_title_contains: str, index: int = 0, then_screenshot: bool = False) -> str | list:
    """Click the centre of the index-th element named like `text` in the
    first window whose title contains window_title_contains (required, so a
    click never lands in whatever window happens to be in front).

    If another window covers the element, the target window is brought to
    the front first; if it is still covered, nothing is sent.
    Refuses elements named like Buy Robux, Purchase, Checkout, Log in, and
    the same pages as click. then_screenshot returns a fresh screenshot too.
    """
    if not window_title_contains:
        raise ValueError("window_title_contains is required")
    found = _elements(text, window_title_contains)
    if index >= len(found):
        raise ValueError(f"{len(found)} element(s) named like {text!r}; no index {index}")
    el = found[index]
    reason = element_refusal(el["name"])
    if reason:
        log(f"REFUSED: {reason}")
        raise PermissionError(f"Refused: {reason}. {REFUSAL_NOTE}")
    chain = _owner_chain(el["_screen"])
    if el["_hwnd"] not in chain:
        _bring_forward(el["_hwnd"])
        time.sleep(0.15)
        chain = _owner_chain(el["_screen"])
    reason = covered_refusal(chain, el["_hwnd"], win32gui.GetWindowText(chain[0]))
    if reason:
        log(f"NOT SENT: {reason}")
        raise RuntimeError(f"Not sent: {reason}.")
    _check_click(el["_screen"])
    pyautogui.click(*el["_screen"])
    log(f"click element {el['name']!r} at {el['_screen']}")
    return _done(f"Clicked {el['type']} {el['name']!r}.", then_screenshot)


@mcp.tool()
def begin_control(task: str = "") -> str:
    """Call when you start using the screen: the orange border stays on until
    end_control (or 10 minutes with no action), so Alex can see Claude is at
    work. task is a few words for the log."""
    overlay.begin()
    log(f"control started: {task}")
    return "Control started; the orange border stays on until end_control."


@mcp.tool()
def end_control() -> str:
    """Call when you are done with the screen: the orange border goes away."""
    log("control ended")
    overlay.end()
    return "Control ended; the orange border is off."


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


@mcp.tool(structured_output=False)
def click(x: float, y: float, button: str = "left", clicks: int = 1, then_screenshot: bool = False) -> str | list:
    """Click at (x, y) in the latest screenshot's pixels.

    button is left, right or middle; clicks is 1 to 3 (2 = double-click).
    The pointer jumps straight there. then_screenshot returns a fresh
    screenshot too (also on drag, scroll, type_text and press_keys).
    """
    if button not in ("left", "right", "middle"):
        raise ValueError("button must be left, right or middle")
    if not 1 <= clicks <= 3:
        raise ValueError("clicks must be 1 to 3")
    sx, sy = _to_screen(x, y)
    _check_click((sx, sy))
    pyautogui.click(sx, sy, clicks=clicks, interval=0.08, button=button)
    log(f"{button} click x{clicks} at {sx},{sy}")
    return _done(f"Clicked {button} x{clicks} at screen {sx},{sy}.", then_screenshot)


@mcp.tool(structured_output=False)
def drag(
    from_x: float, from_y: float, to_x: float, to_y: float, button: str = "left", then_screenshot: bool = False
) -> str | list:
    """Press at (from_x, from_y), drag to (to_x, to_y) and release (screenshot pixels)."""
    if button not in ("left", "right", "middle"):
        raise ValueError("button must be left, right or middle")
    fx, fy = _to_screen(from_x, from_y)
    tx, ty = _to_screen(to_x, to_y)
    _check_click((fx, fy), (tx, ty))
    pyautogui.moveTo(fx, fy, duration=0.1)
    pyautogui.dragTo(tx, ty, duration=0.5, button=button)
    log(f"drag {fx},{fy} -> {tx},{ty}")
    return _done(f"Dragged from screen {fx},{fy} to {tx},{ty}.", then_screenshot)


@mcp.tool(structured_output=False)
def scroll(x: float, y: float, amount: int, then_screenshot: bool = False) -> str | list:
    """Scroll the wheel at (x, y): positive amount scrolls up, negative down (in notches)."""
    sx, sy = _to_screen(x, y)
    pyautogui.moveTo(sx, sy, duration=0.1)
    pyautogui.scroll(amount * 120)
    log(f"scroll {amount} at {sx},{sy}")
    return _done(f"Scrolled {amount} at screen {sx},{sy}.", then_screenshot)


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
        pair = (_INPUT * 2)()
        for inp, flags in zip(pair, (0x0004, 0x0004 | 0x0002)):  # KEYEVENTF_UNICODE, then KEYUP
            inp.type = 1  # INPUT_KEYBOARD
            inp.ki = _KEYBDINPUT(0, unit, flags, 0, 0)
        # Down and up in one call, so nothing can come between them.
        ctypes.windll.user32.SendInput(2, pair, ctypes.sizeof(_INPUT))
    time.sleep(0.03)


TEXT_FORMATS = {1, 13}  # CF_TEXT, CF_UNICODETEXT


def _open_clipboard() -> None:
    """OpenClipboard, retrying while another app briefly holds it."""
    for _ in range(20):
        try:
            win32clipboard.OpenClipboard()
            return
        except Exception:  # noqa: BLE001 - pywintypes.error while held elsewhere
            time.sleep(0.05)
    raise RuntimeError("the clipboard is busy in another app; try again")


def _clipboard_without_text() -> bool:
    """True when the clipboard holds something (an image, files) but no
    text: a paste would lose it. Text with extra formats (HTML, RTF from a
    browser or Word) is fine: its plain text is restored."""
    formats, f = set(), 0
    while True:
        f = win32clipboard.EnumClipboardFormats(f)
        if not f:
            break
        formats.add(f)
    return bool(formats) and not formats & TEXT_FORMATS


def _paste(text: str) -> bool:
    """Ctrl+V the text, then put back the text the clipboard held.

    Returns False without touching anything when the clipboard holds no
    text but something else (an image, copied files), so the caller types
    keys instead.
    """
    _open_clipboard()
    try:
        if _clipboard_without_text():
            return False
        try:
            saved = win32clipboard.GetClipboardData(win32clipboard.CF_UNICODETEXT)
        except TypeError:  # no text on the clipboard
            saved = None
        win32clipboard.EmptyClipboard()
        win32clipboard.SetClipboardData(win32clipboard.CF_UNICODETEXT, text)
    finally:
        win32clipboard.CloseClipboard()
    pyautogui.hotkey("ctrl", "v")
    time.sleep(0.3)  # the app reads the clipboard after the key press
    _open_clipboard()
    try:
        win32clipboard.EmptyClipboard()
        if saved is not None:
            win32clipboard.SetClipboardData(win32clipboard.CF_UNICODETEXT, saved)
    finally:
        win32clipboard.CloseClipboard()
    return True


@mcp.tool(structured_output=False)
def type_text(
    text: str, window_title_contains: str, method: str = "paste", then_screenshot: bool = False
) -> str | list:
    """Type text into the focused field.

    method "paste" (default) puts the text on the clipboard, presses Ctrl+V
    and restores the clipboard text: exact and fast (if the clipboard holds
    only an image or files, it types keys instead so they aren't lost). "keys" sends it key by key
    (newlines press Enter), for places that ignore paste, such as games.
    window_title_contains (required): the window to type into; it is
    brought to the front if needed, and nothing is sent if that fails.
    Refuses password, 2FA or one-time code, CAPTCHA and payment fields, and
    sign-in, verification and checkout pages. Never try to get around it.
    """
    if method not in ("paste", "keys"):
        raise ValueError('method must be "paste" or "keys"')
    _check(text, window_title_contains)
    if method == "paste" and _paste(text):
        log(f"pasted {len(text)} characters")
        return _done(f"Typed {len(text)} characters (paste).", then_screenshot)
    for ch in text.replace("\r", ""):
        if ch == "\n":
            pyautogui.press("enter")
        elif ch == "\t":
            pyautogui.press("tab")
        else:
            _type_char(ch)
    log(f"typed {len(text)} characters")
    return _done(f"Typed {len(text)} characters.", then_screenshot)


@mcp.tool(structured_output=False)
def press_keys(keys: str, window_title_contains: str, then_screenshot: bool = False) -> str | list:
    """Press a key or combination, such as "enter", "esc", "ctrl+s", "alt+tab".

    Names are PyAutoGUI key names joined with "+". Same refusals and
    required window_title_contains check as type_text.
    """
    parts = [k.strip().lower() for k in keys.split("+") if k.strip()]
    unknown = [k for k in parts if k not in pyautogui.KEYBOARD_KEYS]
    if not parts or unknown:
        raise ValueError(f"unknown key name(s): {unknown or keys!r}")
    _check("", window_title_contains)
    pyautogui.hotkey(*parts)
    log(f"keys {'+'.join(parts)}")
    return _done(f"Pressed {'+'.join(parts)}.", then_screenshot)


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


def _bring_forward(target: int) -> None:
    try:
        HwndWrapper(target).set_focus()
    except Exception:  # noqa: BLE001 - Windows' foreground lock; try the Alt trick
        if win32gui.IsIconic(target):
            win32gui.ShowWindow(target, 9)  # SW_RESTORE
        pyautogui.press("alt")
        try:
            win32gui.SetForegroundWindow(target)
        except Exception:  # noqa: BLE001 - the caller checks the result
            pass


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
    _bring_forward(target)
    title = win32gui.GetWindowText(target)
    if win32gui.GetForegroundWindow() != target:
        raise RuntimeError(f"Windows did not let {title!r} come to the front; click on it instead.")
    log(f"focus {title!r}")
    return f"Focused {title!r}."


class TokenAuth:
    """Rejects any HTTP request without the bearer token."""

    def __init__(self, app, token: str):
        self.app = app
        self.expected = f"Bearer {token}".encode()

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http" and scope["path"] == "/health":
            # Liveness only, so status.ps1 needs no token; reveals nothing.
            await send({"type": "http.response.start", "status": 200, "headers": []})
            await send({"type": "http.response.body", "body": b"ok"})
            return
        if scope["type"] == "http":
            headers = dict(scope.get("headers") or [])
            if headers.get(b"authorization") != self.expected:
                await send({"type": "http.response.start", "status": 401, "headers": []})
                await send({"type": "http.response.body", "body": b"unauthorized"})
                return
        await self.app(scope, receive, send)


def _log_to_file() -> None:
    """Without a console (pythonw, the logon task), log to server.log."""
    STATE_DIR.mkdir(exist_ok=True)
    path = STATE_DIR / "server.log"
    if path.exists() and path.stat().st_size > 1_000_000:
        path.replace(STATE_DIR / "server.log.1")
    stream = open(path, "a", encoding="utf-8", buffering=1)  # noqa: SIM115 - lives as long as the process
    sys.stdout = sys.stderr = stream


def main() -> None:
    if sys.stdout is None or "--log" in sys.argv:
        _log_to_file()
    if not TOKEN_FILE.exists():
        sys.exit(f"No token at {TOKEN_FILE}. Run start.ps1 once, which creates it.")
    token = TOKEN_FILE.read_text(encoding="utf-8").strip()
    app = TokenAuth(mcp.streamable_http_app(), token)
    log(f"screen-control listening on http://127.0.0.1:{PORT}/mcp")
    log("Claude can now see this screen and use the mouse and keyboard.")
    log("Stop: tools\\screen-control\\stop.ps1 (or Ctrl+C in its window). Mouse into a corner aborts an action.")
    uvicorn.run(app, host="127.0.0.1", port=PORT, log_level="warning")


if __name__ == "__main__":
    main()
