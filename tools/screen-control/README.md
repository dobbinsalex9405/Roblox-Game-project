# Screen control

A small local MCP server that lets Claude Code on Alex's Windows laptop see
the screen and use the mouse and keyboard: for the clicks the browser tools
cannot do (Roblox's thumbnail uploader, Studio play tests, native file
dialogs). It runs only while Alex has started it, and `stop.ps1` stops it.

## Start and stop

```powershell
powershell -ExecutionPolicy Bypass -File tools\screen-control\start.ps1
```

The first run creates `.venv` here and installs `requirements.txt` (Python
3.11+ from python.org, no admin rights). The window prints every action
Claude takes. **Close the window or press Ctrl+C to stop.** Moving the mouse
hard into a screen corner aborts the action in progress.

Without a console (started with `pythonw`, or with `--log`) the server
writes the same lines to `%USERPROFILE%\.screen-control\server.log`.

```powershell
powershell -ExecutionPolicy Bypass -File tools\screen-control\status.ps1   # health check; exit 0 when running
powershell -ExecutionPolicy Bypass -File tools\screen-control\stop.ps1     # off switch, however it was started
```

`status.ps1` calls `GET /health`, the one route that needs no token (it
answers `ok` and nothing else). A second copy of the server cannot start
while one holds the port.

## Always on (Alex sets this up)

To start the server hidden at every logon, Alex adds a shortcut named
`Claude screen control` to the Startup folder (Win+R, `shell:startup`) with
this target:

```
<repo>\tools\screen-control\.venv\Scripts\pythonw.exe "<repo>\tools\screen-control\server.py"
```

Deleting the shortcut turns that off; `stop.ps1` stops the running copy.
Claude does not create startup entries itself.

## Register with Claude Code (once per laptop)

```powershell
powershell -ExecutionPolicy Bypass -File tools\screen-control\register.ps1
```

This adds `screen-control` to Claude Code's user config, so every new
session on the laptop, Remote Control threads included, gets the tools.
While the server is stopped, `claude mcp list` shows it as failed to connect
and Claude cannot touch the screen. Sessions started before the server was
up need a restart (or `/mcp` reconnect) to see the tools.

The server listens on `127.0.0.1:8765` only (`SCREEN_CONTROL_PORT` changes
it; re-run `register.ps1` after) and rejects any request without the token
in `%USERPROFILE%\.screen-control\token`. The token lives outside AppData
because Store-installed apps such as the Claude app get a private copy of
AppData.

## Tools

| Tool | What it does |
| --- | --- |
| `screenshot(monitor=1)` | JPEG of a monitor, longest edge at most 1568 px, plus its scale and the foreground window's title |
| `zoom(x0, y0, x1, y1)` | Close-up of part of the latest screenshot at full detail, for small text and buttons |
| `find_elements(text, window_title_contains)` | Buttons, fields, menu items whose accessible name contains `text`, with their centre |
| `click_element(text, index)` | Clicks such an element by name: no pixel hunting, survives layout changes |
| `list_monitors()` | Monitors with position and size |
| `click(x, y, button, clicks)` | Jumps straight to the point and clicks; `clicks=2` double-clicks |
| `move_mouse(x, y)` | Hover |
| `drag(from_x, from_y, to_x, to_y)` | Press, drag, release |
| `scroll(x, y, amount)` | Wheel notches; positive is up |
| `type_text(text)` | Types into the focused field; `\n` presses Enter |
| `press_keys(keys)` | `enter`, `esc`, `ctrl+s`, `alt+tab`… (PyAutoGUI key names) |
| `list_windows()` | Visible windows, foreground first |
| `focus_window(title_contains / handle)` | Brings a window to the front |

Coordinates are pixels in the **latest screenshot**; the server scales them
to the screen. Take a fresh screenshot after anything changes the layout, or
pass `then_screenshot=True` to `click`, `click_element`, `drag`, `scroll`,
`type_text` or `press_keys` to get one back with the result.

`find_elements` and `click_element` read Windows UI Automation, so they work
in native apps (Studio, file dialogs, Explorer, Notepad) and in Edge. Chrome
usually hides page contents from it: in Chrome, click by screenshot
coordinates, or use the Chrome browser tools.

Uploading a file through a web page: click the page's upload button, wait
for the Windows "Open" dialog, `type_text` the full path into "File name",
then `press_keys("enter")`.

## Hard limits

- **Never types into a password, 2FA or one-time code, CAPTCHA or payment
  field, or on a sign-in, verification or checkout page.** Before every
  `type_text` and `press_keys` the server reads the focused field through
  Windows UI Automation and refuses when the field is a password field, its
  name or id says password, code, CAPTCHA, card, CVV and the like, or the
  window title says sign in, log in, verification, checkout, payment or buy
  Robux. If the field cannot be read, it refuses too. Text that looks like a
  `.ROBLOSECURITY` cookie is refused anywhere. When a Chrome or Edge page
  is focused but the browser does not say which field (Chrome usually hides
  page contents), typing is refused, since a password box would look the
  same; the address bar and other exposed fields are fine. The word lists are in
  `guard.py`, tested by `tests/test_guard.py`.
- Claude must not work around a refusal (on-screen keyboard, saved-password
  suggestions, pasting with the mouse). Those steps are Alex's, as are
  sign-ins, purchases and account settings (`CLAUDE.md`, "Never").
- **No clicks or drags on sign-in, verification, CAPTCHA or payment
  pages** (same window-title words, checked for the foreground window and
  the window under the pointer), so a click cannot confirm a purchase or
  answer a CAPTCHA. Pages whose titles don't say so are not caught; the
  project rules still apply to every click.
- It runs only while Alex has it on: the Startup shortcut Alex made, or `start.ps1`. Claude never creates startup entries.

## Tests

```sh
python -m unittest discover -s tools/screen-control/tests
```

CI runs these on Linux; the guard has no Windows imports.
