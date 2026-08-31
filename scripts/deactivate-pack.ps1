<#
.SYNOPSIS
    Removes a pack's entry from world_behavior_packs.json /
    world_resource_packs.json by UUID, so it stops loading for the world.
    Does not delete the pack's files from server\behavior_packs or
    resource_packs - just deactivates it. Restart the server to take effect.

.EXAMPLE
    .\scripts\deactivate-pack.ps1 -PackId 9c49a642-c83e-477b-825a-bd27e3249ac6
#>

param(
    [Parameter(Mandatory=$true)][string]$PackId,
    [string]$WorldName = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root "server"
$worldsDir = Join-Path $serverDir "worlds"

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

$removedAny = $false
foreach ($fileName in "world_behavior_packs.json", "world_resource_packs.json") {
    $activationFile = Join-Path $worldPath $fileName
    if (-not (Test-Path $activationFile)) { continue }
    $raw = Get-Content $activationFile -Raw
    if (-not $raw.Trim()) { continue }

    $entries = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in @(ConvertFrom-Json $raw)) {
        if ($item -and $item.pack_id) { $entries.Add($item) }
    }

    $before = $entries.Count
    $kept = New-Object 'System.Collections.Generic.List[object]'
    foreach ($e in $entries) {
        if ($e.pack_id -ne $PackId) { $kept.Add($e) }
    }

    if ($kept.Count -lt $before) {
        $removedAny = $true
        if ($kept.Count -eq 0) {
            Set-Content $activationFile "[]"
        } else {
            $json = ConvertTo-Json -InputObject $kept -Depth 5
            if ($kept.Count -eq 1 -and -not $json.TrimStart().StartsWith('[')) { $json = "[$json]" }
            Set-Content $activationFile $json
        }
        Write-Host "Removed $PackId from $fileName" -ForegroundColor Green
    }
}

if (-not $removedAny) {
    Write-Warning "Pack $PackId was not found active in world '$WorldName' - nothing changed."
} else {
    Write-Host ""
    Write-Host "Restart the server (scripts\start.ps1) for this to take effect." -ForegroundColor Cyan
}
