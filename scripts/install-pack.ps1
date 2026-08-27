<#
.SYNOPSIS
    Copies a behavior/resource pack folder into the running server's
    behavior_packs or resource_packs directory. Does NOT activate it for a
    world - see addons\README.md for the world_behavior_packs.json step.
#>

param(
    [Parameter(Mandatory=$true)][string]$PackPath,
    [Parameter(Mandatory=$true)][ValidateSet("behavior","resource")][string]$Type
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root "server"

if (-not (Test-Path $serverDir)) {
    Write-Error "server\ not found. Run .\scripts\setup.ps1 first."
    exit 1
}
if (-not (Test-Path $PackPath)) {
    Write-Error "Pack path not found: $PackPath"
    exit 1
}

$manifestPath = Join-Path $PackPath "manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-Error "No manifest.json found in $PackPath - is this an unzipped pack folder?"
    exit 1
}

$destRoot = Join-Path $serverDir ($(if ($Type -eq "behavior") { "behavior_packs" } else { "resource_packs" }))
New-Item -ItemType Directory -Force -Path $destRoot | Out-Null

$packName = Split-Path -Leaf (Resolve-Path $PackPath)
$dest = Join-Path $destRoot $packName
Copy-Item -Recurse -Force $PackPath $dest

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
Write-Host "Installed '$packName' to $destRoot" -ForegroundColor Green
Write-Host ""
Write-Host "Now activate it by adding this to server\worlds\<your level>\world_$($Type)_packs.json:" -ForegroundColor Cyan
$version = $manifest.header.version -join ", "
Write-Host "  { ""pack_id"": ""$($manifest.header.uuid)"", ""version"": [$version] }"
