<#
.SYNOPSIS
    Scans a folder for .mcpack/.mcaddon files, installs every pack found
    inside them, and activates each one for the server's world - all in
    one pass.

.EXAMPLE
    .\scripts\install-addons.ps1
    (defaults to scanning your Downloads folder)

.EXAMPLE
    .\scripts\install-addons.ps1 -SourceFolder "C:\Users\stu\Downloads\MyPacks"

.NOTES
    A .mcpack is a zip containing one pack (a manifest.json at its root).
    A .mcaddon is a zip that can contain several packs, each in its own
    subfolder. This script handles both, and both behavior and resource
    packs, by reading each manifest.json's module type.
#>

param(
    [string]$SourceFolder = (Join-Path $env:USERPROFILE "Downloads"),
    [string]$WorldName = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root "server"
$worldsDir = Join-Path $serverDir "worlds"

if (-not (Test-Path $serverDir)) {
    Write-Error "server\ not found. Run .\scripts\setup.ps1 first."
    exit 1
}
if (-not (Test-Path $SourceFolder)) {
    Write-Error "Folder not found: $SourceFolder"
    exit 1
}
if (-not (Test-Path $worldsDir)) {
    Write-Error "No worlds\ folder yet under server\ - start the server once, or import a world (scripts\import-world.ps1) first."
    exit 1
}
if (-not $WorldName) {
    $worldDirs = Get-ChildItem $worldsDir -Directory
    if ($worldDirs.Count -eq 1) {
        $WorldName = $worldDirs[0].Name
    } else {
        Write-Error "Multiple worlds found under server\worlds - pass -WorldName <name>. Found: $($worldDirs.Name -join ', ')"
        exit 1
    }
}
$worldPath = Join-Path $worldsDir $WorldName

$packFiles = Get-ChildItem $SourceFolder -File | Where-Object { $_.Extension -in ".mcpack", ".mcaddon" }
if (-not $packFiles) {
    Write-Warning "No .mcpack or .mcaddon files found in $SourceFolder"
    exit 0
}

$workDir = Join-Path $env:TEMP "mcserver-addons-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

$installed = @()

foreach ($file in $packFiles) {
    Write-Host "Extracting $($file.Name)..." -ForegroundColor Cyan
    $extractDir = Join-Path $workDir $file.BaseName
    $tempZip = Join-Path $workDir "$($file.BaseName).zip"
    Copy-Item $file.FullName $tempZip
    Expand-Archive -Path $tempZip -DestinationPath $extractDir -Force
    Remove-Item $tempZip

    # A pack's manifest.json can be at the extracted root (.mcpack) or one
    # level down per-pack (.mcaddon bundling several packs).
    $manifests = Get-ChildItem $extractDir -Recurse -Filter "manifest.json"

    foreach ($manifestFile in $manifests) {
        $packDir = $manifestFile.Directory
        $manifest = Get-Content $manifestFile.FullName -Raw | ConvertFrom-Json
        $moduleTypes = $manifest.modules | ForEach-Object { $_.type }

        if ($moduleTypes -contains "resources") {
            $type = "resource"
        } else {
            # "data" and "script" modules are both behavior-pack content.
            $type = "behavior"
        }

        $destRoot = Join-Path $serverDir ($(if ($type -eq "behavior") { "behavior_packs" } else { "resource_packs" }))
        New-Item -ItemType Directory -Force -Path $destRoot | Out-Null
        $packName = "$($file.BaseName)_$($packDir.Name)"
        $dest = Join-Path $destRoot $packName
        Copy-Item -Recurse -Force $packDir.FullName $dest

        # Activate for the world.
        $activationFile = Join-Path $worldPath ($(if ($type -eq "behavior") { "world_behavior_packs.json" } else { "world_resource_packs.json" }))
        $entries = @()
        if (Test-Path $activationFile) {
            $raw = Get-Content $activationFile -Raw
            if ($raw.Trim()) { $entries = @(ConvertFrom-Json $raw) }
        }
        $packId = $manifest.header.uuid
        $version = @($manifest.header.version)
        if (-not ($entries | Where-Object { $_.pack_id -eq $packId })) {
            $entries += [PSCustomObject]@{ pack_id = $packId; version = $version }
            ($entries | ConvertTo-Json -Depth 5) | Set-Content $activationFile
        }

        $installed += "$($manifest.header.name) [$type] (from $($file.Name))"
        Write-Host "  Installed + activated: $($manifest.header.name) [$type]" -ForegroundColor Green
    }
}

Remove-Item -Recurse -Force $workDir

Write-Host ""
Write-Host "Done. Installed $($installed.Count) pack(s) for world '$WorldName':" -ForegroundColor Cyan
$installed | ForEach-Object { Write-Host "  - $_" }
Write-Host ""
Write-Host "Restart the server (scripts\start.ps1) for these to take effect." -ForegroundColor Yellow
