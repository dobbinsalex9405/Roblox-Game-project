"""Orange border around the screen while Claude is using it.

`begin()` turns it on for a whole task and `end()` turns it off. Every tool
call also calls `touch()`, which shows it for at least IDLE_SECONDS. A task
left open with no action for SESSION_TIMEOUT (a session that died) ends by
itself. It never takes focus, lets clicks through and is left out of screen
captures, so it is in nobody's way, including Claude's own screenshots.
"""

from __future__ import annotations

import ctypes
import threading
import time

IDLE_SECONDS = 6.0
SESSION_TIMEOUT = 600.0
COLOR = "#ff8a00"
THICKNESS = 6
KEY = "#010203"  # painted inside the border; made fully transparent

_last = 0.0
_session = False
_started = False


def touch() -> None:
    global _last, _session, _started
    now = time.monotonic()
    if now - _last >= SESSION_TIMEOUT:
        _session = False  # a task left open that long has ended
    _last = now
    if not _started:
        _started = True
        threading.Thread(target=_run, name="overlay", daemon=True).start()


def begin() -> None:
    global _session
    touch()
    _session = True


def end() -> None:
    global _session, _last
    _session = False
    _last = 0.0


def visible(now: float) -> bool:
    idle = now - _last
    return idle < IDLE_SECONDS or (_session and idle < SESSION_TIMEOUT)


def _run() -> None:
    import tkinter as tk

    user32 = ctypes.windll.user32
    previous = user32.GetForegroundWindow()
    root = tk.Tk()
    root.withdraw()  # never shown by Tk itself: showing would take focus
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    root.configure(bg=KEY)
    root.attributes("-transparentcolor", KEY)
    # The whole virtual screen (all monitors).
    x, y = user32.GetSystemMetrics(76), user32.GetSystemMetrics(77)
    w, h = user32.GetSystemMetrics(78), user32.GetSystemMetrics(79)
    root.geometry(f"{w}x{h}+{x}+{y}")
    canvas = tk.Canvas(root, bg=KEY, highlightthickness=0, width=w, height=h)
    canvas.pack()
    t = THICKNESS
    for box in ((0, 0, w, t), (0, h - t, w, h), (0, 0, t, h), (w - t, 0, w, h)):
        canvas.create_rectangle(*box, fill=COLOR, outline=COLOR)
    root.update_idletasks()

    hwnd = int(root.wm_frame(), 16)
    GWL_EXSTYLE = -20
    WS_EX_LAYERED, WS_EX_TRANSPARENT, WS_EX_TOOLWINDOW, WS_EX_NOACTIVATE = 0x80000, 0x20, 0x80, 0x8000000
    style = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
    user32.SetWindowLongW(
        hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE
    )
    user32.SetWindowDisplayAffinity(hwnd, 0x11)  # WDA_EXCLUDEFROMCAPTURE (Windows 10 2004+)
    # Starting Tk activates its hidden window; hand focus straight back.
    root.update()
    if previous and user32.GetForegroundWindow() != previous:
        user32.SetForegroundWindow(previous)

    shown = [None]

    def tick() -> None:
        want = visible(time.monotonic())
        if want != shown[0]:
            # SW_SHOWNOACTIVATE / SW_HIDE: show without taking focus.
            user32.ShowWindow(hwnd, 4 if want else 0)
            if want:
                user32.SetWindowPos(hwnd, -1, 0, 0, 0, 0, 0x13)  # HWND_TOPMOST; NOSIZE|NOMOVE|NOACTIVATE
            shown[0] = want
        root.after(200, tick)

    tick()
    root.mainloop()
