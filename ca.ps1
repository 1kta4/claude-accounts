<#
  ca - run Claude Code on one of several accounts.

  Every account is its own config folder (CLAUDE_CONFIG_DIR), so each keeps
  its own login. Skills, plugins, agents, commands, memory and settings are
  shared with your main ~/.claude folder.

    ca                      list accounts
    ca add <name>           add an account and log in once
    ca <name> [claude args] start claude on that account (ca work -c)
    ca main [claude args]   start claude on your main account
    ca shortcut <name> [-Folder <path>] [-Desktop]
                            make a Start menu (and desktop) shortcut
    ca relink <name>        repair the shared links of an account
    ca remove <name> [-Yes] delete an account (asks first)
#>

$ErrorActionPreference = 'Stop'

# CA_HOME stands in for your home folder (handy for trying ca out safely).
$HomeDir = if ($env:CA_HOME) { $env:CA_HOME } else { $HOME }
$MainDir = Join-Path $HomeDir '.claude'
$AccountsDir = Join-Path $HomeDir '.claude-accounts'
$StartMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'Claude accounts'
$Reserved = @('add', 'list', 'ls', 'remove', 'rm', 'relink', 'shortcut', 'help', 'main')

# Folders every account reads straight from ~/.claude (directory junctions).
$SharedDirs = @(
  'skills', 'plugins', 'agents', 'commands', 'output-styles', 'hooks',
  'projects', 'plans', 'todos', 'file-history'
)

# Files Claude Code replaces whole when it saves them, which would cut a link,
# so these are copied instead: the newer copy wins, before and after each run.
$SharedFiles = @('settings.json', 'settings.local.json', 'CLAUDE.md', 'keybindings.json')

function Write-Info([string]$Text) { Write-Host $Text -ForegroundColor DarkGray }

function Get-AccountDir([string]$Name) { Join-Path $AccountsDir $Name }

function Test-Junction([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  return ($null -ne $item) -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Remove-Junction([string]$Path) {
  # rmdir drops the link itself and never touches what it points to.
  cmd /c rmdir "$Path" | Out-Null
}

function Assert-Name([string]$Name) {
  if ([string]::IsNullOrWhiteSpace($Name)) { throw 'Give the account a name, for example: ca add work' }
  if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$') {
    throw "'$Name' is not a usable name: letters, digits, - and _ only, up to 32 characters."
  }
  if ($Reserved -contains $Name.ToLower()) { throw "'$Name' is a ca command; pick another name." }
}

function Assert-Account([string]$Name) {
  Assert-Name $Name
  if (-not (Test-Path -LiteralPath (Get-AccountDir $Name))) {
    throw "No account '$Name'. Add it with: ca add $Name"
  }
}

function Get-Email([string]$ConfigFile) {
  if (-not (Test-Path -LiteralPath $ConfigFile)) { return $null }
  # A plain match: Windows PowerShell's ConvertFrom-Json refuses this file
  # whenever it holds two project paths that differ only in letter case.
  $text = Get-Content -LiteralPath $ConfigFile -Raw
  $found = [regex]::Match($text, '"oauthAccount"\s*:\s*\{[^{}]*?"emailAddress"\s*:\s*"([^"]+)"')
  if ($found.Success) { return $found.Groups[1].Value }
  return $null
}

function Sync-SharedFiles([string]$Dir) {
  foreach ($name in $SharedFiles) {
    $main = Join-Path $MainDir $name
    $mine = Join-Path $Dir $name
    $hasMain = Test-Path -LiteralPath $main
    $hasMine = Test-Path -LiteralPath $mine

    if ($hasMain -and (-not $hasMine -or (Get-Item $main).LastWriteTimeUtc -gt (Get-Item $mine).LastWriteTimeUtc)) {
      Copy-Item -LiteralPath $main -Destination $mine -Force
    } elseif ($hasMine -and (-not $hasMain -or (Get-Item $mine).LastWriteTimeUtc -gt (Get-Item $main).LastWriteTimeUtc)) {
      Copy-Item -LiteralPath $mine -Destination $main -Force
    }
  }
}

function Connect-SharedDirs([string]$Dir) {
  foreach ($name in $SharedDirs) {
    $main = Join-Path $MainDir $name
    $mine = Join-Path $Dir $name

    if (Test-Junction $mine) { continue }

    if (Test-Path -LiteralPath $mine) {
      $isEmpty = -not (Get-ChildItem -LiteralPath $mine -Force | Select-Object -First 1)
      if ($isEmpty) {
        Remove-Item -LiteralPath $mine -Force
      } elseif (-not (Test-Path -LiteralPath $main)) {
        # The account made it first: move it into main so every account shares it.
        Move-Item -LiteralPath $mine -Destination $main
      } else {
        Write-Warning "$mine has files of its own and is not shared. Move what you want to keep into $main, delete it, then run: ca relink"
        continue
      }
    }

    if (-not (Test-Path -LiteralPath $main)) { New-Item -ItemType Directory -Path $main | Out-Null }
    New-Item -ItemType Junction -Path $mine -Target $main | Out-Null
  }
}

function Connect-Account([string]$Dir) {
  if (-not (Test-Path -LiteralPath $MainDir)) { New-Item -ItemType Directory -Path $MainDir | Out-Null }
  Connect-SharedDirs $Dir
  Sync-SharedFiles $Dir
}

function Invoke-Claude([string]$Name, [object[]]$ClaudeArgs) {
  $previous = $env:CLAUDE_CONFIG_DIR
  $dir = $null

  if ($Name -ne 'main') {
    Assert-Account $Name
    $dir = Get-AccountDir $Name
    Connect-Account $dir
    $env:CLAUDE_CONFIG_DIR = $dir
  } else {
    Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
  }

  try {
    & claude @ClaudeArgs
  } finally {
    if ($null -eq $previous) {
      Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
    } else {
      $env:CLAUDE_CONFIG_DIR = $previous
    }
    if ($null -ne $dir) { Sync-SharedFiles $dir }
  }
}

function Show-Accounts {
  $rows = @([pscustomobject]@{ Account = 'main'; Email = Get-Email (Join-Path $HomeDir '.claude.json'); Folder = $MainDir })

  if (Test-Path -LiteralPath $AccountsDir) {
    foreach ($folder in Get-ChildItem -LiteralPath $AccountsDir -Directory | Sort-Object Name) {
      $rows += [pscustomobject]@{
        Account = $folder.Name
        Email = Get-Email (Join-Path $folder.FullName '.claude.json')
        Folder = $folder.FullName
      }
    }
  }

  foreach ($row in $rows) { if (-not $row.Email) { $row.Email = '(not logged in)' } }
  $rows | Format-Table -AutoSize | Out-String | Write-Host
  Write-Info 'Start one with: ca <account>    Add one with: ca add <name>'
}

function New-Shortcut([string]$Name, [string]$Folder, [bool]$OnDesktop) {
  if ($Name -ne 'main') { Assert-Account $Name }
  if (-not $Folder) { $Folder = $HomeDir }
  if (-not (Test-Path -LiteralPath $Folder)) { throw "No folder $Folder" }

  $script = $PSCommandPath
  $shell = New-Object -ComObject WScript.Shell
  $places = @($StartMenuDir)
  if ($OnDesktop) { $places += [Environment]::GetFolderPath('Desktop') }

  foreach ($place in $places) {
    if (-not (Test-Path -LiteralPath $place)) { New-Item -ItemType Directory -Path $place | Out-Null }
    $path = Join-Path $place "Claude ($Name).lnk"
    $link = $shell.CreateShortcut($path)
    $link.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $link.Arguments = "-NoLogo -NoExit -ExecutionPolicy Bypass -File `"$script`" $Name"
    $link.WorkingDirectory = (Resolve-Path -LiteralPath $Folder).Path
    $link.Description = "Claude Code on the $Name account"
    $link.Save()
    Write-Info "Shortcut: $path"
  }
}

function Add-Account([string]$Name, [object[]]$Rest) {
  Assert-Name $Name
  $dir = Get-AccountDir $Name
  if (Test-Path -LiteralPath $dir) { throw "Account '$Name' already exists. Start it with: ca $Name" }

  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  Connect-Account $dir
  New-Shortcut $Name $null $false
  Write-Host "Added '$Name'. Log in with the account you want for it; this is the only time you need to." -ForegroundColor Green

  if ($Rest -notcontains '-NoLogin') {
    Invoke-Claude $Name @('auth', 'login')
  }
}

function Remove-Account([string]$Name, [bool]$Confirmed) {
  Assert-Account $Name
  $dir = Get-AccountDir $Name
  if (-not $Confirmed) {
    $answer = Read-Host "Delete account '$Name' and its login? Shared skills, memory and settings stay. Type the name to confirm"
    if ($answer -ne $Name) { Write-Info 'Nothing deleted.'; return }
  }

  # Drop the junctions first so deleting the folder cannot reach ~/.claude.
  foreach ($item in Get-ChildItem -LiteralPath $dir -Force) {
    if (Test-Junction $item.FullName) { Remove-Junction $item.FullName }
  }
  $left = Get-ChildItem -LiteralPath $dir -Force -Recurse | Where-Object { Test-Junction $_.FullName }
  if ($left) { throw "Stopped: $dir still holds links ($($left[0].FullName)). Remove them by hand." }

  Remove-Item -LiteralPath $dir -Recurse -Force
  foreach ($place in @($StartMenuDir, [Environment]::GetFolderPath('Desktop'))) {
    $path = Join-Path $place "Claude ($Name).lnk"
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
  }
  Write-Host "Removed '$Name'." -ForegroundColor Green
}

function Get-Option([object[]]$List, [string]$Flag) {
  $at = [array]::IndexOf($List, $Flag)
  if ($at -ge 0 -and $at + 1 -lt $List.Count) { return [string]$List[$at + 1] }
  return $null
}

$command = if ($args.Count -gt 0) { [string]$args[0] } else { 'list' }
$rest = if ($args.Count -gt 1) { @($args[1..($args.Count - 1)]) } else { @() }

try {
  switch ($command.ToLower()) {
    { $_ -in 'list', 'ls' } { Show-Accounts }
    'add' { Add-Account ([string]$rest[0]) @($rest | Select-Object -Skip 1) }
    { $_ -in 'remove', 'rm' } { Remove-Account ([string]$rest[0]) ($rest -contains '-Yes') }
    'relink' { Assert-Account ([string]$rest[0]); Connect-Account (Get-AccountDir ([string]$rest[0])); Write-Info 'Links repaired.' }
    'shortcut' { New-Shortcut ([string]$rest[0]) (Get-Option $rest '-Folder') ($rest -contains '-Desktop') }
    { $_ -in 'help', '-h', '--help' } { Get-Content -LiteralPath $PSCommandPath -TotalCount 16 | Select-Object -Skip 1 | Write-Host }
    default { Invoke-Claude $command $rest }
  }
} catch {
  Write-Host "ca: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
