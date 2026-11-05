# Off switch: stops the running screen-control server, however it was
# started. A "Claude screen control" shortcut in the Startup folder (if Alex
# added one) starts it again at the next logon; delete it to stop that too.
#
#   powershell -ExecutionPolicy Bypass -File tools\screen-control\stop.ps1
$serverPy = Join-Path $PSScriptRoot 'server.py'
$procs = Get-CimInstance Win32_Process -Filter "Name='python.exe' or Name='pythonw.exe'" |
    Where-Object { $_.CommandLine -and $_.CommandLine.Contains($serverPy) }
if (-not $procs) {
    Write-Host 'Screen control is not running.'
    return
}
foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host "Screen control stopped ($(@($procs).Count) process(es))."
