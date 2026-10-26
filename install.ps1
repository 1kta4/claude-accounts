# Installs ca: copies ca.ps1 to %LOCALAPPDATA%\claude-accounts and adds a
# `ca` command to your PowerShell profile. Run it again to update.

$ErrorActionPreference = 'Stop'

$target = Join-Path $env:LOCALAPPDATA 'claude-accounts'
New-Item -ItemType Directory -Path $target -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ca.ps1') -Destination $target -Force

$line = "function ca { & `"$target\ca.ps1`" @args }"
if (-not (Test-Path -LiteralPath $PROFILE)) {
  New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
$current = Get-Content -LiteralPath $PROFILE -Raw
if ($null -eq $current -or -not $current.Contains($line)) {
  Add-Content -LiteralPath $PROFILE -Value "`r`n# claude-accounts`r`n$line" -Encoding UTF8
}

Write-Host "Installed. Open a new PowerShell window, then run: ca add <name>" -ForegroundColor Green
