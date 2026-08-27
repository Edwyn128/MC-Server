<#
.SYNOPSIS
    Starts the Bedrock Dedicated Server from .\server. Run scripts\setup.ps1 first.
#>

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root "server"
$exe = Join-Path $serverDir "bedrock_server.exe"

if (-not (Test-Path $exe)) {
    Write-Error "bedrock_server.exe not found in .\server. Run .\scripts\setup.ps1 first."
    exit 1
}

Push-Location $serverDir
try {
    Write-Host "Starting Bedrock server (Ctrl+C to stop)..." -ForegroundColor Cyan
    & $exe
} finally {
    Pop-Location
}
