# Health check: is the screen-control server answering on 127.0.0.1?
# Exits 0 when it is, 1 when not.
#
#   powershell -ExecutionPolicy Bypass -File tools\screen-control\status.ps1
param([switch]$Quiet)
$port = if ($env:SCREEN_CONTROL_PORT) { $env:SCREEN_CONTROL_PORT } else { '8765' }
try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 "http://127.0.0.1:$port/health"
    $ok = $r.StatusCode -eq 200
} catch {
    $ok = $false
}
$task = Get-ScheduledTask -TaskName 'Claude screen control' -ErrorAction SilentlyContinue
if (-not $Quiet) {
    if ($ok) { Write-Host "Screen control is running on 127.0.0.1:$port." }
    else { Write-Host "Screen control is NOT running on 127.0.0.1:$port." }
    if ($task) { Write-Host 'Starts at logon: yes (install-autostart.ps1 -Remove turns that off).' }
    else { Write-Host 'Starts at logon: no (install-autostart.ps1 turns that on).' }
}
if (-not $ok) { exit 1 }
