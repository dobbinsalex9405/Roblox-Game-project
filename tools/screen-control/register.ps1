# Registers the server with Claude Code for this Windows user (user scope),
# so every Claude Code session on this laptop, Remote Control threads
# included, gets the screen-control tools. Run once; safe to re-run.
#
#   powershell -ExecutionPolicy Bypass -File tools\screen-control\register.ps1
#
# The tools only work while start.ps1 is running; otherwise the server shows
# as failed to connect and Claude cannot touch the screen.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'token.ps1')
$token = Get-ScreenControlToken
$port = if ($env:SCREEN_CONTROL_PORT) { $env:SCREEN_CONTROL_PORT } else { '8765' }

$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) {
    # The Claude desktop app keeps its own Claude Code build here.
    $claude = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Claude-Data') -Recurse -Filter claude.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like '*\claude-code\*' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $claude) { throw 'Claude Code (claude.exe) not found.' }

# Drop an earlier registration; on a first run this prints an error, ignored.
$ErrorActionPreference = 'Continue'
& $claude mcp remove --scope user screen-control 2>&1 | Out-Null
$ErrorActionPreference = 'Stop'
& $claude mcp add --scope user --transport http screen-control "http://127.0.0.1:$port/mcp" --header "Authorization: Bearer $token"
if ($LASTEXITCODE -ne 0) { throw 'claude mcp add failed.' }
Write-Host 'Registered. New Claude Code sessions get the screen-control tools while start.ps1 runs.'
