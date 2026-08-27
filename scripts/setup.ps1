<#
.SYNOPSIS
    Downloads and installs the official Minecraft Bedrock Dedicated Server (BDS)
    into .\server, without ever touching an existing world/config on re-run.

.NOTES
    The download URL is resolved from Mojang's public download-links API. That
    endpoint is undocumented and community-observed (used by minecraft.net's own
    download page and by widely-used tools like itzg/docker-minecraft-bedrock-server),
    not an officially published contract, so it can change without notice. If it
    fails, this script falls back to asking you to paste a URL you copied yourself
    from https://www.minecraft.net/en-us/download/server/bedrock after accepting
    the EULA there.

    Running this script is you accepting the Minecraft EULA and Privacy Policy:
      https://www.minecraft.net/en-us/eula
      https://go.microsoft.com/fwlink/?LinkId=521839
#>

param(
    [string]$ManualDownloadUrl = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root "server"
$configTemplate = Join-Path $root "config\server.properties.template"

Write-Host "== MC-Server setup ==" -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $serverDir | Out-Null

function Get-BdsWindowsUrl {
    $apiUrl = "https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"
    try {
        $resp = Invoke-RestMethod -Uri $apiUrl -Method Get -UserAgent "MC-Server-setup-script"
        $entry = $resp.result.links | Where-Object { $_.downloadType -eq "serverBedrockWindows" }
        if ($entry -and $entry.downloadUrl) {
            return $entry.downloadUrl
        }
    } catch {
        Write-Warning "Could not resolve download URL automatically: $_"
    }
    return $null
}

$downloadUrl = $ManualDownloadUrl
if (-not $downloadUrl) {
    $downloadUrl = Get-BdsWindowsUrl
}

if (-not $downloadUrl) {
    Write-Host ""
    Write-Host "Automatic download-link resolution failed (Mojang's API may have changed)." -ForegroundColor Yellow
    Write-Host "1. Open https://www.minecraft.net/en-us/download/server/bedrock in a browser"
    Write-Host "2. Accept the EULA/Privacy Policy checkbox"
    Write-Host "3. Right-click the Windows download button -> Copy Link"
    Write-Host "4. Re-run: .\scripts\setup.ps1 -ManualDownloadUrl ""<paste the link>"""
    exit 1
}

Write-Host "Downloading: $downloadUrl"
$zipPath = Join-Path $root "bds.zip"
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UserAgent "Mozilla/5.0"

# Preserve an existing install (world, allowlist, permissions, properties) across updates.
$preserve = @("worlds", "server.properties", "allowlist.json", "permissions.json", "behavior_packs", "resource_packs", "world_behavior_packs.json", "world_resource_packs.json")
$backupDir = Join-Path $root "_preserve_tmp"
if (Test-Path $serverDir) {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    foreach ($item in $preserve) {
        $src = Join-Path $serverDir $item
        if (Test-Path $src) {
            Move-Item -Force $src (Join-Path $backupDir $item)
        }
    }
}

Write-Host "Extracting..."
Expand-Archive -Path $zipPath -DestinationPath $serverDir -Force
Remove-Item $zipPath

# Restore anything preserved from a prior install.
if (Test-Path $backupDir) {
    Get-ChildItem $backupDir | ForEach-Object {
        Copy-Item -Force -Recurse $_.FullName $serverDir
    }
    Remove-Item -Recurse -Force $backupDir
}

# First-run only: seed server.properties from our template. Never overwrite a live config.
$liveProps = Join-Path $serverDir "server.properties"
if (-not (Test-Path $liveProps) -or (Get-Item $liveProps).Length -eq 0) {
    Copy-Item $configTemplate $liveProps -Force
    Write-Host "Seeded server.properties from config\server.properties.template" -ForegroundColor Green
} else {
    Write-Host "Existing server.properties preserved (not overwritten)." -ForegroundColor Yellow
}

# Record the EULA acceptance BDS itself checks for.
"eula=true`nprivacy_notice_confirmed=true" | Set-Content (Join-Path $serverDir "eula_and_privacy_confirmation.txt") -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review server\server.properties (name, gamemode, max-players)"
Write-Host "  2. Run .\scripts\open-firewall.ps1 (once, as Administrator) to allow inbound traffic"
Write-Host "  3. Run .\scripts\start.ps1 to launch the server"
Write-Host "  4. See NETWORKING.md if you want console/mobile friends to join over the internet"
