"""What Alex sees while Claude is using the screen.

An orange border runs around the screen. `begin()` turns it on for a whole
task and `end()` turns it off. Every tool call also calls `touch()`, which
shows it for at least IDLE_SECONDS. A task left open with no action for
SESSION_TIMEOUT (a session that died) ends by itself. The border never takes
focus, lets clicks through and is left out of screen captures, so it is in
nobody's way, including Claude's own screenshots.

The first time a Claude session reaches for the screen (after `end()`,
after SESSION_TIMEOUT of quiet, after the server starts, or when a
different session than the last one announced takes over), `start()` shows
a prompt in the middle of the main screen: "Claude is about to use your
screen", the task, a countdown of PROMPT_SECONDS and a Stop button. The tool
call waits for it. When the countdown runs out the work goes ahead and later
calls in the same task don't ask again. Stop refuses that call and every
call for STOP_SECONDS. The prompt never takes focus either, so Alex's typing
is not interrupted.

Run `python overlay.py --demo "what Claude is doing"` on the laptop to see
the prompt without the server.
"""

from __future__ import annotations

import ctypes
import threading
import time

IDLE_SECONDS = 6.0
SESSION_TIMEOUT = 600.0
PROMPT_SECONDS = 4
STOP_SECONDS = 600.0
COLOR = "#ff8a00"
THICKNESS = 6
KEY = "#010203"  # painted inside the border; made fully transparent

# Prompt card colours.
CARD_BG = "#1c1c1e"
CARD_TEXT = "#ffffff"
CARD_MUTED = "#c7c7cc"
CARD_WIDTH = 460

# start() answers.
ASKED = "asked"  # the prompt ran its countdown; go ahead
QUIET = "quiet"  # already announced in this task; go ahead
UNSHOWN = "unshown"  # the prompt could not be shown; go ahead (as without the border)
STOPPED = "stopped"  # Alex pressed Stop now or within STOP_SECONDS; send nothing

_last = 0.0
_session = False
_started = False
_NOBODY = object()
_announced_for: object = _NOBODY  # the client the last prompt was for
_stopped_at: float | None = None

_lock = threading.Lock()
_pending: dict | None = None  # the prompt the Tk thread should show next


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
    global _session, _last, _announced_for
    _session = False
    _last = 0.0
    _announced_for = _NOBODY


def visible(now: float) -> bool:
    idle = now - _last
    return idle < IDLE_SECONDS or (_session and idle < SESSION_TIMEOUT)


def needs_prompt(now: float, client: object = None) -> bool:
    """True when this use of the screen is the first in a task: nothing has
    been announced since the server started or the last end(), the last
    prompt was for another client (another Claude session), or the screen
    has been left alone for SESSION_TIMEOUT."""
    return _announced_for is _NOBODY or _announced_for is not client or now - _last >= SESSION_TIMEOUT


def stopped(now: float) -> bool:
    """True for STOP_SECONDS after Alex pressed Stop."""
    return _stopped_at is not None and now - _stopped_at < STOP_SECONDS


def start(task: str = "", action: str = "", client: object = None) -> str:
    """Call before every use of the screen. Shows the prompt when this is
    the first use in a task and waits for it. client identifies the caller
    (its MCP session). Returns ASKED, QUIET or UNSHOWN (go ahead) or
    STOPPED (send nothing)."""
    global _announced_for, _stopped_at
    now = time.monotonic()
    if stopped(now):
        return STOPPED
    if not needs_prompt(now, client):
        return QUIET
    touch()  # the border comes on with the prompt
    answer = _ask(task, action)
    if answer == STOPPED:
        _stopped_at = time.monotonic()
        end()
        return STOPPED
    _announced_for = client
    touch()  # count the quiet time from now, not from before the prompt
    return answer


def _ask(task: str, action: str) -> str:
    """Hand the prompt to the Tk thread and wait for Alex or the countdown.

    Tests replace this. If the Tk thread never picks it up (it failed to
    start), the call goes ahead after a short wait, the same as when the
    border can't be shown."""
    global _pending
    request = {"task": task, "action": action, "answer": UNSHOWN, "done": threading.Event()}
    with _lock:
        _pending = request
    if not request["done"].wait(PROMPT_SECONDS + 3):
        with _lock:
            if _pending is request:
                _pending = None
            else:  # it is on screen: let it finish
                request["done"].wait(PROMPT_SECONDS + 3)
    return request["answer"]


def _take_pending() -> dict | None:
    global _pending
    with _lock:
        request, _pending = _pending, None
    return request


def prompt_lines(task: str, action: str, seconds_left: int) -> tuple[str, str, str]:
    """The prompt's heading, task line and countdown line."""
    task = " ".join(task.split())
    if len(task) > 120:
        task = task[:119] + "…"
    if task:
        detail = f"Task: {task}"
    elif action:
        detail = f"No task given. First action: {action}"
    else:
        detail = "No task given."
    return (
        "Claude is about to use your screen",
        detail,
        f"Starting in {seconds_left} s. Press Stop to keep Claude off the screen "
        f"for {round(STOP_SECONDS / 60)} minutes.",
    )


class _Card:
    """The centred prompt. Built and driven only on the Tk thread; no
    Windows calls in here, so it also renders on Linux for previews."""

    def __init__(self, tk, root):
        self.tk = tk
        self.win = tk.Toplevel(root)
        self.win.withdraw()
        self.win.overrideredirect(True)
        self.win.attributes("-topmost", True)
        self.win.configure(bg=COLOR)  # shows as a 3 px orange edge
        body = tk.Frame(self.win, bg=CARD_BG, padx=24, pady=20)
        body.pack(padx=3, pady=3, fill="both", expand=True)
        font = "Segoe UI"
        self.title = tk.Label(body, bg=CARD_BG, fg=CARD_TEXT, font=(font, 15, "bold"), anchor="w", justify="left")
        self.title.pack(fill="x")
        wrap = CARD_WIDTH - 2 * 24 - 6
        self.detail = tk.Label(
            body, bg=CARD_BG, fg=CARD_TEXT, font=(font, 11), anchor="w", justify="left", wraplength=wrap
        )
        self.detail.pack(fill="x", pady=(8, 0))
        self.count = tk.Label(
            body, bg=CARD_BG, fg=CARD_MUTED, font=(font, 10), anchor="w", justify="left", wraplength=wrap
        )
        self.count.pack(fill="x", pady=(8, 16))
        # A Label rather than a Button: it looks the same everywhere and
        # takes the click without needing the window to be active.
        self.stop = tk.Label(
            body, text="Stop", bg=COLOR, fg="#000000", font=(font, 11, "bold"), padx=22, pady=6, cursor="hand2"
        )
        self.stop.pack(anchor="e")
        self.stop.bind("<ButtonRelease-1>", lambda _e: self._finish(STOPPED))
        self.request: dict | None = None
        self.left = 0
        self.timer = None

    def show(self, request: dict, screen_w: int, screen_h: int) -> tuple[int, int, int, int]:
        """Fill in the prompt and start its countdown. Returns where it goes
        (x, y, width, height), centred on a screen_w x screen_h screen."""
        self.request = request
        self.left = PROMPT_SECONDS
        self._draw()
        self.win.update_idletasks()
        h = self.win.winfo_reqheight()
        x, y = (screen_w - CARD_WIDTH) // 2, (screen_h - h) // 2
        self.win.geometry(f"{CARD_WIDTH}x{h}+{x}+{y}")
        self.win.update_idletasks()
        self.timer = self.win.after(1000, self._step)
        return x, y, CARD_WIDTH, h

    def _draw(self) -> None:
        r = self.request
        heading, detail, count = prompt_lines(r["task"], r["action"], self.left)
        self.title.configure(text=heading)
        self.detail.configure(text=detail)
        self.count.configure(text=count)

    def _step(self) -> None:
        if self.request is None:
            return
        self.left -= 1
        if self.left <= 0:
            self._finish(ASKED)
        else:
            self._draw()
            self.timer = self.win.after(1000, self._step)

    def _finish(self, answer: str) -> None:
        request, self.request = self.request, None
        if request is None:
            return
        if self.timer is not None:
            self.win.after_cancel(self.timer)  # no stale tick on the next prompt
            self.timer = None
        request["answer"] = answer
        self.on_hide()
        request["done"].set()

    def on_hide(self) -> None:  # replaced by _run with the Windows hide call
        self.win.withdraw()


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
    card = _Card(tk, root)
    root.update_idletasks()

    GWL_EXSTYLE = -20
    WS_EX_LAYERED, WS_EX_TRANSPARENT, WS_EX_TOOLWINDOW, WS_EX_NOACTIVATE = 0x80000, 0x20, 0x80, 0x8000000
    hwnd = int(root.wm_frame(), 16)
    style = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
    user32.SetWindowLongW(
        hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE
    )
    user32.SetWindowDisplayAffinity(hwnd, 0x11)  # WDA_EXCLUDEFROMCAPTURE (Windows 10 2004+)
    # The prompt takes clicks (for Stop) but never focus, and stays visible
    # to screen captures so it can be checked from a screenshot. Claude's
    # own screenshots never see it: tool calls wait while it is up.
    card_hwnd = int(card.win.wm_frame(), 16)
    style = user32.GetWindowLongW(card_hwnd, GWL_EXSTYLE)
    user32.SetWindowLongW(card_hwnd, GWL_EXSTYLE, style | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE)
    card.on_hide = lambda: user32.ShowWindow(card_hwnd, 0)  # SW_HIDE
    # Starting Tk activates its hidden window; hand focus straight back.
    root.update()
    if previous and user32.GetForegroundWindow() != previous:
        user32.SetForegroundWindow(previous)

    # The prompt is centred on the main screen, which starts at 0, 0.
    main_w, main_h = user32.GetSystemMetrics(0), user32.GetSystemMetrics(1)

    def show_without_focus(target: int, rect: tuple[int, int, int, int] | None = None) -> None:
        # SW_SHOWNOACTIVATE, then HWND_TOPMOST with NOACTIVATE (and
        # NOSIZE|NOMOVE unless a place is given).
        user32.ShowWindow(target, 4)
        if rect:
            user32.SetWindowPos(target, -1, *rect, 0x10)
        else:
            user32.SetWindowPos(target, -1, 0, 0, 0, 0, 0x13)

    shown = [None]

    def tick() -> None:
        want = visible(time.monotonic())
        if want != shown[0]:
            if want:
                show_without_focus(hwnd)
            else:
                user32.ShowWindow(hwnd, 0)  # SW_HIDE
            shown[0] = want
        if card.request is None:
            request = _take_pending()
            if request is not None:
                show_without_focus(card_hwnd, card.show(request, main_w, main_h))
        root.after(200, tick)

    tick()
    root.mainloop()


def _demo(task: str) -> None:
    print("Showing the prompt; press Stop or wait", PROMPT_SECONDS, "seconds.")
    print("Answer:", start(task, "demo"))
    time.sleep(1.5)  # leave the border up a moment so it can be seen
    end()


if __name__ == "__main__":
    import sys

    if len(sys.argv) >= 2 and sys.argv[1] == "--demo":
        _demo(" ".join(sys.argv[2:]) or "Demo: checking the prompt")
    else:
        sys.exit('usage: python overlay.py --demo ["what Claude is doing"]')
