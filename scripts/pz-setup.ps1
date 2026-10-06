<#
.SYNOPSIS
    Downloads SteamCMD (if needed) and uses it to install/update the Project
    Zomboid Dedicated Server into .\server-pz.

.NOTES
    Steam App ID for the Project Zomboid Dedicated Server is 380870 - this is
    widely documented for self-hosting, but if this script ever errors out
    saying the app isn't found, double-check that ID against Steam/SteamDB
    before assuming the script is wrong.

    The dedicated server is free to download via an anonymous SteamCMD login
    (no Steam account credentials needed).

    Safe to re-run any time to update the server - SteamCMD only downloads
    what changed.
#>

param(
    [string]$SteamCmdUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$steamCmdDir = Join-Path $root "steamcmd"
$serverDir = Join-Path $root "server-pz"

Write-Host "== Project Zomboid server setup ==" -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $steamCmdDir "steamcmd.exe"))) {
    Write-Host "Downloading SteamCMD..."
    New-Item -ItemType Directory -Force -Path $steamCmdDir | Out-Null
    $zipPath = Join-Path $root "steamcmd.zip"
    try {
        Invoke-WebRequest -Uri $SteamCmdUrl -OutFile $zipPath -UserAgent "Mozilla/5.0"
    } catch {
        Write-Host ""
        Write-Host "Could not download SteamCMD automatically: $_" -ForegroundColor Yellow
        Write-Host "Download it yourself from https://developer.valvesoftware.com/wiki/SteamCMD"
        Write-Host "and unzip it into: $steamCmdDir"
        exit 1
    }
    Expand-Archive -Path $zipPath -DestinationPath $steamCmdDir -Force
    Remove-Item $zipPath
} else {
    Write-Host "SteamCMD already present." -ForegroundColor Green
}

New-Item -ItemType Directory -Force -Path $serverDir | Out-Null

Write-Host "Installing/updating Project Zomboid Dedicated Server (this can take a while)..." -ForegroundColor Cyan
$steamCmdExe = Join-Path $steamCmdDir "steamcmd.exe"
& $steamCmdExe +force_install_dir $serverDir +login anonymous +app_update 380870 validate +quit

if ($LASTEXITCODE -ne 0) {
    Write-Error "SteamCMD exited with code $LASTEXITCODE - check the output above for what failed."
    exit 1
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. .\scripts\pz-deploy-config.ps1 -RconPassword ""<pick a real password>"""
Write-Host "  2. .\scripts\pz-open-firewall.ps1 (once, as Administrator)"
Write-Host "  3. .\scripts\pz-start.ps1"
