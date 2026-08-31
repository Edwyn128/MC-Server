<#
.SYNOPSIS
    Moves the current world aside (as a timestamped backup, never deleted)
    so the server generates a brand new world on next start - useful after
    installing world-gen-affecting Add-Ons, so new blocks/structures can
    actually spawn instead of only existing in already-generated chunks.

.EXAMPLE
    .\scripts\reset-world.ps1

.NOTES
    After this runs:
      1. .\scripts\start.ps1 once to let BDS generate the fresh world folder,
         then Ctrl+C to stop it again.
      2. .\scripts\install-addons.ps1 -SourceFolder <your addons folder> to
         reactivate your Add-Ons for the new world.
      3. .\scripts\start.ps1 for real.
#>

param(
    [string]$WorldName = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root "server"
$worldsDir = Join-Path $serverDir "worlds"

if (-not (Test-Path $worldsDir)) {
    Write-Error "No worlds\ folder under server\ - nothing to reset."
    exit 1
}
if (Get-Process -Name "bedrock_server" -ErrorAction SilentlyContinue) {
    Write-Error "bedrock_server.exe is running. Stop it first (Ctrl+C in its console window), then re-run this script."
    exit 1
}
if (-not $WorldName) {
    $worldDirs = Get-ChildItem $worldsDir -Directory | Where-Object { $_.Name -notmatch ' - backup \d{4}-\d{2}-\d{2}_\d{6}$' }
    if ($worldDirs.Count -eq 1) {
        $WorldName = $worldDirs[0].Name
    } else {
        Write-Error "Multiple worlds found under server\worlds - pass -WorldName <name>. Found: $($worldDirs.Name -join ', ')"
        exit 1
    }
}
$worldPath = Join-Path $worldsDir $WorldName
if (-not (Test-Path $worldPath)) {
    Write-Error "World folder not found: $worldPath"
    exit 1
}

$backupName = "$WorldName - backup $(Get-Date -Format 'yyyy-MM-dd_HHmmss')"
$backupPath = Join-Path $worldsDir $backupName
Move-Item $worldPath $backupPath

Write-Host "Moved '$WorldName' to a backup - it still exists, just renamed:" -ForegroundColor Green
Write-Host "  server\worlds\$backupName"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. .\scripts\start.ps1  (let it generate the new world, then Ctrl+C once it says 'Server started.')"
Write-Host "  2. .\scripts\install-addons.ps1 -SourceFolder <your addons folder>  (reactivate your Add-Ons for the new world)"
Write-Host "  3. .\scripts\start.ps1  (for real this time)"
