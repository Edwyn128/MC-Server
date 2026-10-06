<#
.SYNOPSIS
    Opens inbound UDP ports for the Project Zomboid server in Windows
    Defender Firewall, matching the ports set in config\pz\pzserver.ini
    (DefaultPort=27075, UDPPort=27076). Run once, as Administrator.

.NOTES
    RCON (default port 27015, TCP) is intentionally NOT opened here - it's
    meant for local/admin use, not public exposure. Only open/forward it if
    you specifically need to manage the server remotely, and use a strong
    RCON password if you do (see pz-deploy-config.ps1).
#>

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Re-run this script from an elevated (Administrator) PowerShell prompt."
    exit 1
}

$rules = @(
    @{ Name = "Project Zomboid Server (UDP 27075)"; Port = 27075 },
    @{ Name = "Project Zomboid Server (UDP 27076)"; Port = 27076 }
)

foreach ($rule in $rules) {
    $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Rule already exists: $($rule.Name)" -ForegroundColor Yellow
    } else {
        New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -Protocol UDP -LocalPort $rule.Port -Action Allow | Out-Null
        Write-Host "Created inbound allow rule: $($rule.Name)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Windows Firewall is configured. For players outside your home network," -ForegroundColor Cyan
Write-Host "you still need to forward UDP 27075 and 27076 on your router, or use a tunnel"
Write-Host "like playit.gg if your ISP has you behind CGNAT - see NETWORKING.md."
