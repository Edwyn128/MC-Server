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
    subfolder, and some creators nest an actual .mcpack/.mcaddon file
    instead of a plain folder - this script unpacks those too.
    A bad or unparseable pack (e.g. a manifest.json with // comments, which
    isn't strict JSON) is skipped with a warning instead of aborting the
    whole batch.

    Pack load order / conflicts: activated packs are appended to
    world_behavior_packs.json / world_resource_packs.json in the order this
    script processes them (roughly alphabetical by filename). When two packs
    both modify the same item/block/entity, Bedrock's pack stack order
    decides which one wins - this script does not try to resolve that for
    you. If two of your add-ons visibly conflict, reorder the entries in
    those two files by hand (or in-game under world settings, if the pack
    manager UI there lets you drag pack order) and restart the server.
#>

param(
    [string]$SourceFolder = (Join-Path $env:USERPROFILE "Downloads"),
    [string]$WorldName = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root "server"
$worldsDir = Join-Path $serverDir "worlds"

function Read-JsonPermissive([string]$path) {
    $text = Get-Content $path -Raw
    # Strip /* */ block comments.
    $text = [regex]::Replace($text, '(?s)/\*.*?\*/', '')
    # Strip // line comments that aren't inside a quoted string.
    $lines = $text -split "`r?`n"
    $cleanedLines = foreach ($line in $lines) {
        $inString = $false
        $sb = New-Object System.Text.StringBuilder
        $i = 0
        while ($i -lt $line.Length) {
            $ch = $line[$i]
            if ($ch -eq '"' -and ($i -eq 0 -or $line[$i - 1] -ne '\')) { $inString = -not $inString }
            if (-not $inString -and $ch -eq '/' -and ($i + 1) -lt $line.Length -and $line[$i + 1] -eq '/') {
                break
            }
            [void]$sb.Append($ch)
            $i++
        }
        $sb.ToString()
    }
    $text = $cleanedLines -join "`n"
    # Strip trailing commas before a closing bracket/brace (also non-strict JSON some creators ship).
    $text = [regex]::Replace($text, ',(\s*[}\]])', '$1')
    return $text | ConvertFrom-Json
}

function Expand-NestedPacks([string]$dir) {
    # Some .mcaddon files bundle sub-packs as actual .mcpack/.mcaddon files
    # instead of plain folders - unpack any found, one level, so their
    # manifest.json becomes visible to the search below.
    $nested = Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in ".mcpack", ".mcaddon" }
    foreach ($n in $nested) {
        $subExtract = Join-Path $n.Directory.FullName "$($n.BaseName)_unpacked"
        if (-not (Test-Path $subExtract)) {
            $tempZip = "$($n.FullName).zip"
            Copy-Item $n.FullName $tempZip
            Expand-Archive -Path $tempZip -DestinationPath $subExtract -Force
            Remove-Item $tempZip
        }
    }
}

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
$failed = @()

foreach ($file in $packFiles) {
    try {
        Write-Host "Extracting $($file.Name)..." -ForegroundColor Cyan
        $extractDir = Join-Path $workDir $file.BaseName
        $tempZip = Join-Path $workDir "$($file.BaseName).zip"
        Copy-Item $file.FullName $tempZip
        Expand-Archive -Path $tempZip -DestinationPath $extractDir -Force
        Remove-Item $tempZip

        Expand-NestedPacks $extractDir

        # A pack's manifest.json can be at the extracted root (.mcpack), one
        # level down per-pack (.mcaddon bundling several packs), or inside a
        # nested archive we just unpacked above.
        $manifests = Get-ChildItem $extractDir -Recurse -Filter "manifest.json"

        if (-not $manifests) {
            Write-Warning "  No manifest.json found anywhere in $($file.Name) - skipping."
            $failed += "$($file.Name): no manifest.json found"
            continue
        }

        foreach ($manifestFile in $manifests) {
            try {
                $packDir = $manifestFile.Directory
                $manifest = Read-JsonPermissive $manifestFile.FullName
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
            } catch {
                Write-Warning "  Could not parse $($manifestFile.FullName): $_"
                $failed += "$($manifestFile.Directory.Name) (from $($file.Name)): $_"
            }
        }
    } catch {
        Write-Warning "Failed to process $($file.Name): $_"
        $failed += "$($file.Name): $_"
    }
}

Remove-Item -Recurse -Force $workDir

Write-Host ""
Write-Host "Done. Installed $($installed.Count) pack(s) for world '$WorldName':" -ForegroundColor Cyan
$installed | ForEach-Object { Write-Host "  - $_" }
if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Skipped $($failed.Count) (see warnings above for details):" -ForegroundColor Yellow
    $failed | ForEach-Object { Write-Host "  - $_" }
}
Write-Host ""
Write-Host "Restart the server (scripts\start.ps1) for these to take effect." -ForegroundColor Yellow
