# Starts the screen-control server in this window. While it runs, Claude can
# see the screen and use the mouse and keyboard. Close the window or press
# Ctrl+C to stop it.
#
#   powershell -ExecutionPolicy Bypass -File tools\screen-control\start.ps1
#
# First run creates .venv next to this file and installs requirements.txt
# (no admin rights needed), and creates the access token.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$venvPy = Join-Path $here '.venv\Scripts\python.exe'

. (Join-Path $here 'token.ps1')
$null = Get-ScreenControlToken

if (-not (Test-Path $venvPy)) {
    Write-Host 'First run: creating the Python environment...'
    py -3 -m venv (Join-Path $here '.venv')
    if ($LASTEXITCODE -ne 0) { throw 'Python 3.11+ is needed (py launcher).' }
}
& $venvPy -m pip install --quiet --disable-pip-version-check -r (Join-Path $here 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'pip install failed.' }

$host.UI.RawUI.WindowTitle = 'Claude screen control (close to stop)'
& $venvPy (Join-Path $here 'server.py')
