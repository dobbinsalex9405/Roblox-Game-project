---
name: screen-control
description: See and control Alex's Windows laptop screen (screenshots, clicks, typing, windows) through the local screen-control MCP server. Use when a task needs a native app or a click the browser tools can't do (Roblox Studio, file upload dialogs, Explorer, desktop apps), or when asked to look at or click on the laptop screen.
---

# Screen control on Alex's laptop

The `screen-control` MCP server (repo: `tools/screen-control/`) gives you
`mcp__screen-control__*` tools. It runs on Alex's Windows laptop from logon
(Startup shortcut) and is registered in Claude Code's user config, so every
session on the laptop has it. An orange border shows on screen while you use it.

## Before you start

1. If the tools are missing or fail to connect, check it is running:
   `powershell -ExecutionPolicy Bypass -File tools\screen-control\status.ps1`
   from the repo folder (`%USERPROFILE%\Roblox-Game-project`).
   If it is not running, tell Alex (don't start it yourself unless Alex asked
   for screen control in this conversation). Sessions opened before it started
   need `/mcp` reconnect or a restart.
2. Alex may be using the laptop. Look before you act: take a screenshot and
   check the foreground window. If Alex is active, ask before clicking.
   Alex being away, or saying you may control it, is the go-ahead.
3. For web pages, prefer the browser tools (Claude in Chrome). Use screen
   control for what they can't do: native dialogs, Studio, desktop apps.

## How to use it

- Call `begin_control("what you are doing")` before your first action and
  `end_control()` as soon as you are done (also when you stop early or hand
  a step to Alex). The orange border stays on in between, so Alex can see
  the screen is in use.
- `screenshot()` first. Every x, y is in **pixels of the latest screenshot**;
  the server scales to the real screen. Re-screenshot after the layout changes,
  or pass `then_screenshot=True` to an action to get one back.
- `zoom(x0, y0, x1, y1)` for small text or buttons (coordinates stay those of
  the full screenshot).
- `click(x, y)` jumps straight there and clicks (`clicks=2` double-click,
  `button="right"`). `drag`, `scroll`, `move_mouse` as named.
- `find_elements(text, window_title_contains)` and
  `click_element(text, window_title_contains, index)` work by on-screen name
  in native apps, file dialogs, Notepad and Edge. Chrome usually hides page
  contents from them: click by coordinates there. If another window covers
  the element, `click_element` brings the target window forward first and
  sends nothing if it is still covered.
- `type_text(text, window_title_contains)` pastes the text exactly (clipboard
  text is restored; if the clipboard holds only an image or files, it types
  keys instead); `method="keys"` sends keystrokes for apps that ignore paste.
  `press_keys("ctrl+s", window_title_contains)` for keys and shortcuts.
  **`window_title_contains` is required**: name the window you mean. The
  Claude app often jumps to the front between calls, so the server brings
  the named window forward first and sends nothing if it can't. Name it
  specifically (check `list_windows()`): the first matching window is used,
  so "Roblox" could pick Studio or a Chrome tab; "Roblox Studio" or
  "Creator Hub - Google Chrome" can't. Click into the target field first.
- `list_windows()`, `focus_window(title_contains)` to switch windows. If
  Windows refuses the focus change, click the window instead.
- Upload a file through a web page: click the page's upload button, then in
  the Windows dialog `type_text("C:\\full\\path.png", "Open")` and
  `press_keys("enter", "Open")`.

## Hard rules

- Never type, paste or press keys in password, 2FA or one-time code, CAPTCHA
  or payment fields, and never click or type on sign-in, verification,
  CAPTCHA, checkout or purchase pages or buttons (Buy Robux, Purchase…).
  The server refuses these; **never work around a refusal** (on-screen
  keyboard, saved-password suggestions, another tool). Hand the step to Alex.
- Never handle Alex's Roblox password, `.ROBLOSECURITY` cookie or 2FA codes,
  never spend Robux or money, never change account or security settings.
- Don't create startup entries, scheduled tasks or other persistence.
- Leave things as you found them: close test windows you opened, don't save
  over Alex's files, and tell Alex about anything that went wrong.

## Off switch

`tools\screen-control\stop.ps1` stops it; deleting the "Claude screen control"
shortcut in the Startup folder (`shell:startup`) stops it starting at logon.
Server log: `%USERPROFILE%\.screen-control\server.log`.
