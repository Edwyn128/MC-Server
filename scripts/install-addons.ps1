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
    # Read as UTF-8 explicitly - Windows PowerShell's default Get-Content
    # encoding guess mangles the Â§-style color codes some pack names use.
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
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

# Activation entries are collected in-memory (via .Add(), never `+=`) and
# written to world_(behavior|resource)_packs.json exactly ONCE at the end.
# Reading-modifying-writing that file once per pack, as an earlier version
# of this script did, hit a PowerShell quirk where ConvertTo-Json collapses
# a single-item collection into a bare object instead of a one-element JSON
# array; the next read-and-append then nested that bare object one level
# deeper, compounding with every pack until the file was unparseable
# garbage BDS silently ignored (packs "installed" but never actually
# activated - no force-download prompt, no visible effect in-game).
function Read-ActivationEntries([string]$activationFile) {
    $list = New-Object 'System.Collections.Generic.List[object]'
    if (Test-Path $activationFile) {
        try {
            $raw = Get-Content $activationFile -Raw
            if ($raw.Trim()) {
                foreach ($item in @(ConvertFrom-Json $raw)) {
                    if ($item -and $item.pack_id) { $list.Add($item) }
                }
            }
        } catch {
            Write-Warning "Existing $activationFile could not be parsed and will be rebuilt from scratch: $_"
        }
    }
    return $list
}

function Write-ActivationEntries([string]$activationFile, $list) {
    if ($list.Count -eq 0) {
        Set-Content $activationFile "[]"
        return
    }
    $json = ConvertTo-Json -InputObject $list -Depth 5
    # A single-element collection piped through ConvertTo-Json emits a bare
    # object ({...}) instead of a one-element array ([{...}]) - force it.
    if ($list.Count -eq 1 -and -not $json.TrimStart().StartsWith('[')) {
        $json = "[$json]"
    }
    Set-Content $activationFile $json
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

$behaviorActivationFile = Join-Path $worldPath "world_behavior_packs.json"
$resourceActivationFile = Join-Path $worldPath "world_resource_packs.json"
$behaviorEntries = Read-ActivationEntries $behaviorActivationFile
$resourceEntries = Read-ActivationEntries $resourceActivationFile

if ($null -eq $behaviorEntries -or $null -eq $resourceEntries) {
    Write-Error "Internal error: activation lists failed to initialize (behavior=$($null -eq $behaviorEntries) resource=$($null -eq $resourceEntries)). PowerShell version: $($PSVersionTable.PSVersion)"
    exit 1
}
Write-Host "Loaded existing activation entries: $($behaviorEntries.Count) behavior, $($resourceEntries.Count) resource." -ForegroundColor DarkGray

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
                if ($null -eq $manifest) {
                    throw "manifest.json parsed to nothing (empty or invalid file)"
                }
                $moduleTypes = @($manifest.modules) | ForEach-Object { $_.type }

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

                # Queue activation for the world (written once, after all packs are processed).
                if ($type -eq "behavior") { $entries = $behaviorEntries } else { $entries = $resourceEntries }
                if ($null -eq $entries) {
                    throw "internal error: activation list for type '$type' was not initialized"
                }
                $packId = $manifest.header.uuid
                $version = @($manifest.header.version)
                if (-not ($entries | Where-Object { $_.pack_id -eq $packId })) {
                    $entries.Add([PSCustomObject]@{ pack_id = $packId; version = $version })
                }

                $installed += "$($manifest.header.name) [$type] (from $($file.Name))"
                Write-Host "  Installed + activated: $($manifest.header.name) [$type]" -ForegroundColor Green
            } catch {
                $lineNum = if ($_.InvocationInfo) { $_.InvocationInfo.ScriptLineNumber } else { "?" }
                Write-Warning "  Could not parse $($manifestFile.FullName): $($_.Exception.Message) [script line $lineNum]"
                $failed += "$($manifestFile.Directory.Name) (from $($file.Name)): $($_.Exception.Message) [line $lineNum]"
            }
        }
    } catch {
        $lineNum = if ($_.InvocationInfo) { $_.InvocationInfo.ScriptLineNumber } else { "?" }
        Write-Warning "Failed to process $($file.Name): $($_.Exception.Message) [script line $lineNum]"
        $failed += "$($file.Name): $($_.Exception.Message) [line $lineNum]"
    }
}

Write-ActivationEntries $behaviorActivationFile $behaviorEntries
Write-ActivationEntries $resourceActivationFile $resourceEntries

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
