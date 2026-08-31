<#
.SYNOPSIS
    One-shot Add-On install: copies a behavior/resource pack into the server
    AND activates it for your world (edits world_behavior_packs.json /
    world_resource_packs.json), so there's no manual JSON editing.

.EXAMPLE
    .\scripts\activate-pack.ps1 -PackPath .\addons\example_starter_kit -Type behavior

.NOTES
    The server must be stopped and restarted (scripts\start.ps1) for a newly
    activated pack to take effect.
#>

param(
    [Parameter(Mandatory=$true)][string]$PackPath,
    [Parameter(Mandatory=$true)][ValidateSet("behavior","resource")][string]$Type,
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
if (-not (Test-Path $PackPath)) {
    Write-Error "Pack path not found: $PackPath"
    exit 1
}
$manifestPath = Join-Path $PackPath "manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-Error "No manifest.json found in $PackPath - is this an unzipped pack folder?"
    exit 1
}

# --- Step 1: copy the pack into server/behavior_packs or server/resource_packs ---
$destRoot = Join-Path $serverDir ($(if ($Type -eq "behavior") { "behavior_packs" } else { "resource_packs" }))
New-Item -ItemType Directory -Force -Path $destRoot | Out-Null
$packName = Split-Path -Leaf (Resolve-Path $PackPath)
$dest = Join-Path $destRoot $packName
Copy-Item -Recurse -Force $PackPath $dest
Write-Host "Copied '$packName' -> $destRoot" -ForegroundColor Green

# --- Step 2: find the world folder ---
if (-not (Test-Path $worldsDir)) {
    Write-Error "No worlds\ folder yet under server\ - start the server once (scripts\start.ps1) to generate the default world, then re-run this script."
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
if (-not (Test-Path $worldPath)) {
    Write-Error "World folder not found: $worldPath"
    exit 1
}

# --- Step 3: activate the pack for that world ---
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$packId = $manifest.header.uuid
$version = @($manifest.header.version)

$activationFile = Join-Path $worldPath ($(if ($Type -eq "behavior") { "world_behavior_packs.json" } else { "world_resource_packs.json" }))

# Loaded into a List and written with -InputObject (not piped) so a
# single-entry file can't collapse into a bare JSON object instead of a
# one-element array - see install-addons.ps1's Read/Write-ActivationEntries
# for the full story on why that corrupts the file for BDS.
$entries = [System.Collections.Generic.List[object]]::new()
if (Test-Path $activationFile) {
    try {
        $raw = Get-Content $activationFile -Raw
        if ($raw.Trim()) {
            foreach ($item in @(ConvertFrom-Json $raw)) {
                if ($item -and $item.pack_id) { $entries.Add($item) }
            }
        }
    } catch {
        Write-Warning "Existing $activationFile could not be parsed and will be rebuilt from scratch: $_"
    }
}

$already = $entries | Where-Object { $_.pack_id -eq $packId }
if ($already) {
    Write-Host "Pack already activated for world '$WorldName' (uuid $packId)." -ForegroundColor Yellow
} else {
    $entries.Add([PSCustomObject]@{ pack_id = $packId; version = $version })
    $json = ConvertTo-Json -InputObject $entries -Depth 5
    if ($entries.Count -eq 1 -and -not $json.TrimStart().StartsWith('[')) {
        $json = "[$json]"
    }
    Set-Content $activationFile $json
    Write-Host "Activated '$packName' for world '$WorldName'." -ForegroundColor Green
}

Write-Host ""
Write-Host "Restart the server for the pack to take effect: stop it (Ctrl+C) and run .\scripts\start.ps1 again." -ForegroundColor Cyan
