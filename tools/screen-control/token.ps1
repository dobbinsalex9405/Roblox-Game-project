# Shared by start.ps1 and register.ps1: the bearer token Claude Code sends to
# the server, kept outside the repo in %USERPROFILE%\.screen-control\token.
# Not AppData: Store-installed apps (the Claude app, Store Python) get their
# own private copy of AppData, so the server and Claude Code would disagree.
function Get-ScreenControlToken {
    $dir = Join-Path $env:USERPROFILE '.screen-control'
    $file = Join-Path $dir 'token'
    if (-not (Test-Path $file)) {
        New-Item -ItemType Directory -Force $dir | Out-Null
        $bytes = New-Object byte[] 32
        [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        $token = -join ($bytes | ForEach-Object { $_.ToString('x2') })
        [IO.File]::WriteAllText($file, $token)
    }
    return ([IO.File]::ReadAllText($file)).Trim()
}
