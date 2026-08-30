<#
.SYNOPSIS
    Imports a .mcworld file (e.g. exported from a Realm) into server/worlds/
    and points server.properties at it.

.EXAMPLE
    .\scripts\import-world.ps1 -WorldFile "C:\Users\stu\Downloads\MyRealm.mcworld"

.NOTES
    A .mcworld file is just a zip of the world folder's contents. Stop the
    server (Ctrl+C in its window) before running this - it edits files under
    server\ that the running server may be holding open.
#>

param(
    [Parameter(Mandatory=$true)][string]$WorldFile,
    [string]$WorldName = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root "server"
$worldsDir = Join-Path $serverDir "worlds"
$propsPath = Join-Path $serverDir "server.properties"

if (-not (Test-Path $serverDir)) {
    Write-Error "server\ not found. Run .\scripts\setup.ps1 first."
    exit 1
}
if (-not (Test-Path $WorldFile)) {
    Write-Error "World file not found: $WorldFile"
    exit 1
}

$running = Get-Process -Name "bedrock_server" -ErrorAction SilentlyContinue
if ($running) {
    Write-Error "bedrock_server.exe is currently running. Stop it (Ctrl+C in its console window), then re-run this script."
    exit 1
}

if (-not $WorldName) {
    $WorldName = [System.IO.Path]::GetFileNameWithoutExtension($WorldFile)
}

New-Item -ItemType Directory -Force -Path $worldsDir | Out-Null
$destWorld = Join-Path $worldsDir $WorldName

if ((Test-Path $destWorld) -and (-not $Force)) {
    Write-Error "server\worlds\$WorldName already exists. Pass -Force to overwrite it, or -WorldName to import under a different name."
    exit 1
}
if (Test-Path $destWorld) {
    Remove-Item -Recurse -Force $destWorld
}

# .mcworld is a zip; Expand-Archive needs a .zip extension to recognize it.
$tempZip = Join-Path $env:TEMP "$WorldName-$(Get-Random).zip"
Copy-Item $WorldFile $tempZip
New-Item -ItemType Directory -Force -Path $destWorld | Out-Null
Expand-Archive -Path $tempZip -DestinationPath $destWorld -Force
Remove-Item $tempZip

Write-Host "Imported world into server\worlds\$WorldName" -ForegroundColor Green

# Point server.properties at the new world.
if (Test-Path $propsPath) {
    $content = Get-Content $propsPath
    if ($content -match '^level-name=') {
        $content = $content -replace '^level-name=.*$', "level-name=$WorldName"
    } else {
        $content += "level-name=$WorldName"
    }
    Set-Content $propsPath $content
    Write-Host "Set level-name=$WorldName in server.properties" -ForegroundColor Green
} else {
    Write-Warning "server.properties not found - set level-name=$WorldName manually before starting."
}

Write-Host ""
Write-Host "Done. Run .\scripts\start.ps1 to launch the server with this world." -ForegroundColor Cyan
Write-Host "Note: any Marketplace add-ons the Realm used may not carry over - only custom/importable content does." -ForegroundColor Yellow
