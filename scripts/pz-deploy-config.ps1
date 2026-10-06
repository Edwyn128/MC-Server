<#
.SYNOPSIS
    Deploys config\pz\pzserver.ini and pzserver_SandboxVars.lua into
    %USERPROFILE%\Zomboid\Server\ - the folder Project Zomboid actually reads
    server configs from (NOT inside the game install directory).

.EXAMPLE
    .\scripts\pz-deploy-config.ps1 -RconPassword "a-real-strong-password"

.NOTES
    The repo's copy of pzserver.ini has RCONPassword left as a placeholder on
    purpose (this repo is public on GitHub) - this script injects the real
    password you pass in only into your LOCAL deployed copy, which is never
    committed to git.

    If a config already exists at the destination, it's backed up first
    (timestamped), never silently overwritten.
#>

param(
    [Parameter(Mandatory=$true)][string]$RconPassword,
    [string]$ServerName = "pzserver"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$srcIni = Join-Path $root "config\pz\pzserver.ini"
$srcLua = Join-Path $root "config\pz\pzserver_SandboxVars.lua"
$destDir = Join-Path $env:USERPROFILE "Zomboid\Server"

if (-not (Test-Path $srcIni) -or -not (Test-Path $srcLua)) {
    Write-Error "Expected config files not found under config\pz\ - run this from the repo root."
    exit 1
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null

$destIni = Join-Path $destDir "$ServerName.ini"
$destLua = Join-Path $destDir "$($ServerName)_SandboxVars.lua"

foreach ($dest in @($destIni, $destLua)) {
    if (Test-Path $dest) {
        $backup = "$dest.bak-$(Get-Date -Format 'yyyy-MM-dd_HHmmss')"
        Copy-Item $dest $backup
        Write-Host "Backed up existing $(Split-Path -Leaf $dest) -> $(Split-Path -Leaf $backup)" -ForegroundColor Yellow
    }
}

$iniContent = (Get-Content $srcIni -Raw) -replace 'RCONPassword=CHANGE_ME_LOCALLY', "RCONPassword=$RconPassword"
Set-Content $destIni $iniContent
Copy-Item $srcLua $destLua -Force

Write-Host "Deployed config for server '$ServerName' to:" -ForegroundColor Green
Write-Host "  $destIni"
Write-Host "  $destLua"
Write-Host ""
Write-Host "Run .\scripts\pz-start.ps1 to launch with this config." -ForegroundColor Cyan
