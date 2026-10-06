<#
.SYNOPSIS
    Starts the Project Zomboid Dedicated Server using the config deployed by
    pz-deploy-config.ps1. Run scripts\pz-setup.ps1 first.
#>

param(
    [string]$ServerName = "pzserver"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root "server-pz"
$startScript = Join-Path $serverDir "StartServer64.bat"

if (-not (Test-Path $startScript)) {
    Write-Error "StartServer64.bat not found in .\server-pz - run .\scripts\pz-setup.ps1 first."
    exit 1
}

Push-Location $serverDir
try {
    Write-Host "Starting Project Zomboid server '$ServerName' (Ctrl+C to stop)..." -ForegroundColor Cyan
    & $startScript -servername $ServerName
} finally {
    Pop-Location
}
